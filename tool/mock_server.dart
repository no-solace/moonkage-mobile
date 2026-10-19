// Mock server cho GĐ 1: thay identity-service khi web và đăng nhập chưa xong.
//
// Chạy:  dart run tool/mock_server.dart
// Mở http://localhost:8090 trên PC để lấy QR; app build với env/mock.json.
//
// Tài khoản: demo@moonkage.vn / 123456 và other@moonkage.vn / 123456.
//
// Giả lập (trạng thái giữ trong bộ nhớ, mất khi tắt):
// - POST /identity-service/api/auth/login              → LoginResponse (docs/auth.md)
// - GET  /identity-service/api/nfc/sessions/{id}         → {sessionId, status: PENDING|VERIFIED, expiresAt}
// - POST /identity-service/api/nfc/sessions/{id}/card    → VERIFIED hoặc REJECTED (gửi một lần, D-20)
// Từ chối: SESSION_EXPIRED (quá 5 phút), SESSION_USED, SESSION_NOT_OWNED, LOCKED,
// BAD_FORMAT và ID_ALREADY_LINKED (tính một lần thử; 5 lần → khóa 15 phút).
// Không in nội dung thẻ ra console.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:jose/jose.dart';
import 'package:moonkage_verify/core/network/api_endpoints.dart';
import 'package:moonkage_verify/features/verify/data/demo_nfc_key.dart';

const _port = 8090;
const _maxAttempts = 5;
const _sessionTtl = Duration(minutes: 5);
const _lockDuration = Duration(minutes: 15);
const _api = ApiEndpoints.identityService;

final _sessionPath = RegExp('^$_api/nfc/sessions/([A-Za-z0-9_-]+)/card\$');
final _random = Random.secure();

final class _User {
  _User(this.email, this.phone, this.fullName);

  final String email;
  final String phone;
  final String fullName;
  final String accountId = _randomHex(8);
  var failedAttempts = 0;
  DateTime? lockedUntil;
}

final class _Session {
  _Session(this.owner, this.createdAt);

  final _User owner;
  final DateTime createdAt;
  Map<String, Object?>? pendingCard;
  var used = false;

  DateTime get expiresAt => createdAt.add(_sessionTtl);
}

final _users = [
  _User('demo@moonkage.vn', '0900000001', 'Nguyen Van Demo'),
  _User('other@moonkage.vn', '0900000002', 'Tran Thi Khac'),
];
const _password = '123456';

final _tokens = <String, _User>{};
final _sessions = <String, _Session>{};
final _linkedIds = <String, _User>{};

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
  stdout
    ..writeln('Mock server đang chạy ở cổng $_port.')
    ..writeln('Mở http://localhost:$_port trên PC để lấy QR.')
    ..writeln('Tài khoản: ${_users.map((u) => u.email).join(', ')} — mật khẩu $_password');
  await for (final request in server) {
    try {
      await _handle(request);
    } on Exception catch (e) {
      stderr.writeln('Lỗi xử lý ${request.method} ${request.uri.path}: ${e.runtimeType}');
      await _error(request, HttpStatus.internalServerError, 'Lỗi mock server');
    }
  }
}

Future<void> _handle(HttpRequest request) async {
  final path = request.uri.path;
  final method = request.method;

  if (method == 'GET' && path == '/') {
    return _send(request, HttpStatus.ok, ContentType.html, _page());
  }
  if (method == 'POST' && path == '/reset') {
    _reset();
    request.response
      ..statusCode = HttpStatus.seeOther
      ..headers.set(HttpHeaders.locationHeader, '/');
    return request.response.close();
  }
  if (method == 'POST' && path == ApiEndpoints.login) return _login(request);

  final getSessionMatch = RegExp('^$_api/nfc/sessions/([A-Za-z0-9_-]+)\$').firstMatch(path);
  if (method == 'GET' && getSessionMatch != null) {
    final user = _authenticate(request);
    if (user == null) return _error(request, HttpStatus.unauthorized, 'Token thiếu hoặc hết hạn');
    final sessionId = getSessionMatch.group(1)!;
    final session = _sessions[sessionId];
    if (session == null || DateTime.now().isAfter(session.expiresAt)) {
      return _error(request, HttpStatus.gone, 'Phiên không tồn tại hoặc đã hết hạn');
    }
    if (session.owner.accountId != user.accountId) {
      return _error(request, HttpStatus.forbidden, 'Phiên thuộc tài khoản khác');
    }
    return _send(
      request,
      HttpStatus.ok,
      ContentType.json,
      jsonEncode({
        'sessionId': sessionId,
        // giống identity-service: phiên đã dùng vẫn đọc được, trả VERIFIED
        'status': session.used ? 'VERIFIED' : 'PENDING',
        'expiresAt': session.expiresAt.toIso8601String(),
      }),
    );
  }

  final match = _sessionPath.firstMatch(path);
  if (match == null) return _error(request, HttpStatus.notFound, 'Không tìm thấy đường dẫn');

  final user = _authenticate(request);
  if (user == null) return _error(request, HttpStatus.unauthorized, 'Token thiếu hoặc hết hạn');
  final sessionId = match.group(1)!;
  if (method != 'POST') {
    return _error(request, HttpStatus.methodNotAllowed, 'Không hỗ trợ $method');
  }
  final result = await _submitCard(user, sessionId, await _readJson(request));
  _log(sessionId, 'card → ${result['status']} ${result['reasonCode'] ?? ''}');
  return _send(request, HttpStatus.ok, ContentType.json, jsonEncode(result));
}

Future<void> _login(HttpRequest request) async {
  final body = await _readJson(request);
  final username = body?['username'];
  final password = body?['password'];
  final user = _users.where((u) => u.email == username || u.phone == username).firstOrNull;
  if (user == null || password != _password) {
    return _error(request, HttpStatus.unauthorized, 'Thông tin đăng nhập không đúng');
  }
  final token = _randomHex(24);
  _tokens[token] = user;
  stdout.writeln('[${_time()}] đăng nhập: ${user.email}');
  return _send(
    request,
    HttpStatus.ok,
    ContentType.json,
    jsonEncode({
      'token': token,
      'refreshToken': _randomHex(24),
      'accountId': user.accountId,
      'userId': user.accountId,
      'email': user.email,
      'phoneNumber': user.phone,
      'fullName': user.fullName,
      'role': 'CUSTOMER',
      'vendorStatus': 'NONE',
      'vendorId': null,
    }),
  );
}

_User? _authenticate(HttpRequest request) {
  final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
  return header.startsWith('Bearer ') ? _tokens[header.substring(7)] : null;
}

/// Kiểm phiên chung cho bước gửi thẻ và xác nhận; null nghĩa là phiên hợp lệ.
Map<String, Object?>? _checkSession(_User user, _Session? session) {
  final now = DateTime.now();
  if (session == null || now.isAfter(session.expiresAt)) return _reject('SESSION_EXPIRED');
  if (session.owner != user) return _reject('SESSION_NOT_OWNED');
  if (session.used) return _reject('SESSION_USED');
  final lockedUntil = user.lockedUntil;
  if (lockedUntil != null && now.isBefore(lockedUntil)) {
    return _reject('LOCKED', lockedUntil: lockedUntil);
  }
  return null;
}

Future<Map<String, Object?>> _submitCard(
  _User user,
  String sessionId,
  Map<String, Object?>? body,
) async {
  final session = _sessions[sessionId];
  final rejected = _checkSession(user, session);
  if (rejected != null) return rejected;
  if (body == null) return _failAttempt(user, 'BAD_FORMAT');

  final mergedBody = Map<String, Object?>.from(body);
  final encryptedFields = body['encryptedFields'];
  if (encryptedFields is String && encryptedFields.isNotEmpty) {
    try {
      final jwe = JsonWebEncryption.fromCompactSerialization(encryptedFields);
      final store = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(demoPrivateKeyJwk));
      final payload = await jwe.getPayload(store);
      final decrypted = payload.jsonContent;
      if (decrypted is Map<String, Object?>) {
        mergedBody.addAll(decrypted);
      } else {
        return _failAttempt(user, 'BAD_FORMAT');
      }
    } on Exception catch (_) {
      return _failAttempt(user, 'BAD_FORMAT');
    }
  }

  final card = _validCard(mergedBody);
  if (card == null) return _failAttempt(user, 'BAD_FORMAT');

  final expiry = DateTime.parse(card['dateOfExpiry']! as String);
  if (!expiry.isAfter(DateTime.now())) {
    return _failAttempt(user, 'CARD_EXPIRED');
  }

  final idNumber = card['idNumber']! as String;
  final linkedTo = _linkedIds[idNumber];
  if (linkedTo != null && linkedTo != user) return _failAttempt(user, 'ID_ALREADY_LINKED');

  session!
    ..used = true
    ..pendingCard = null;
  _linkedIds[idNumber] = user;
  user.failedAttempts = 0;
  return {'status': 'VERIFIED'};
}

final _idNumber = RegExp(r'^\d{12}$');
final _unaccentedName = RegExp(r'^[A-Z]+( [A-Z]+)*$');
const _textFields = ['nationality', 'placeOfBirth', 'placeOfResidence'];
const _dateFields = ['dateOfBirth', 'dateOfIssue', 'dateOfExpiry'];

/// Kiểm lại phía máy chủ, không tin kết quả kiểm ở app. Trả về bản đã chuẩn hóa hoặc null.
Map<String, Object?>? _validCard(Map<String, Object?> body) {
  final idNumber = body['idNumber'];
  final fullName = body['fullName'];
  final gender = body['gender'];
  if (idNumber is! String || !_idNumber.hasMatch(idNumber)) return null;
  if (fullName is! String || !_unaccentedName.hasMatch(fullName)) return null;
  if (gender != 'MALE' && gender != 'FEMALE') return null;

  final dates = <String, DateTime>{};
  for (final field in _dateFields) {
    final value = body[field];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) return null;
    dates[field] = parsed;
  }
  if (dates['dateOfBirth']!.isAfter(dates['dateOfIssue']!)) return null;
  if (!dates['dateOfIssue']!.isBefore(dates['dateOfExpiry']!)) return null;

  for (final field in _textFields) {
    final value = body[field];
    if (value is! String || value.trim().isEmpty) return null;
  }

  return {
    'idNumber': idNumber,
    'fullName': fullName,
    for (final field in _dateFields) field: body[field],
    'gender': gender,
    for (final field in _textFields) field: (body[field]! as String).trim(),
  };
}

Map<String, Object?> _failAttempt(_User user, String reasonCode) {
  user.failedAttempts++;
  final attemptsLeft = _maxAttempts - user.failedAttempts;
  if (attemptsLeft > 0) return _reject(reasonCode, attemptsLeft: attemptsLeft);
  user.failedAttempts = 0;
  final lockedUntil = DateTime.now().add(_lockDuration);
  user.lockedUntil = lockedUntil;
  return _reject(reasonCode, attemptsLeft: 0, lockedUntil: lockedUntil);
}

Map<String, Object?> _reject(String reasonCode, {int? attemptsLeft, DateTime? lockedUntil}) => {
  'status': 'REJECTED',
  'reasonCode': reasonCode,
  'attemptsLeft': attemptsLeft,
  'lockedUntil': lockedUntil?.toUtc().toIso8601String(),
};

void _reset() {
  _sessions.clear();
  _linkedIds.clear();
  for (final user in _users) {
    user
      ..failedAttempts = 0
      ..lockedUntil = null;
  }
  stdout.writeln('[${_time()}] đã xóa trạng thái');
}

String _newSession(_User owner, {DateTime? createdAt, String prefix = ''}) {
  final id = '$prefix${_randomHex(16)}';
  _sessions[id] = _Session(owner, createdAt ?? DateTime.now());
  return id;
}

String _page() {
  final demo = _users.first;
  final other = _users.last;
  final valid = _newSession(demo);
  final expired = _newSession(
    demo,
    createdAt: DateTime.now().subtract(_sessionTtl * 2),
    prefix: 'expired-',
  );
  final notOwned = _newSession(other);

  String userState(_User u) {
    final locked = u.lockedUntil;
    final lock = locked != null && DateTime.now().isBefore(locked)
        ? 'tạm khóa đến ${_time(locked)}'
        : 'không khóa';
    final linked = _linkedIds.values.where((owner) => owner == u).length;
    return '<li><b>${u.email}</b>: đã xác minh $linked CCCD · '
        'sai ${u.failedAttempts}/$_maxAttempts · $lock</li>';
  }

  String qr(String id, String title, String value, String note) =>
      '''
<div class="card"><h2>$title</h2><div id="$id" class="qr"></div>
<p class="note">$note</p><p><code>$value</code></p></div>
<script>new QRCode(document.getElementById('$id'), ${jsonEncode(value)});</script>''';

  return '''
<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Moonkage Verify Mock</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
<style>
  body { font-family: system-ui, sans-serif; margin: 24px; background: #fff; color: #111; }
  .row { display: flex; gap: 40px; flex-wrap: wrap; }
  .card { max-width: 280px; }
  .qr { padding: 16px; background: #fff; display: inline-block; }
  .note { color: #555; }
  code { font-size: 11px; word-break: break-all; }
</style>
</head>
<body>
<h1>Moonkage Verify — mock server</h1>
<p>Đăng nhập app bằng <b>${demo.email}</b> / $_password (tài khoản thứ hai: ${other.email}).</p>
<ul>${_users.map(userState).join()}</ul>
<div class="row">
${qr('ok', 'Phiên mới', 'moonkage-verify:v1:$valid', 'Của ${demo.email}, còn 5 phút.')}
${qr('expired', 'Phiên hết hạn', 'moonkage-verify:v1:$expired', '→ SESSION_EXPIRED')}
${qr('other', 'Phiên tài khoản khác', 'moonkage-verify:v1:$notOwned', 'Của ${other.email} → SESSION_NOT_OWNED khi app đăng nhập ${demo.email}.')}
${qr('bad', 'QR sai dạng', 'https://example.com/$valid', 'App báo lỗi, không gọi máy chủ.')}
</div>
<p><a href="/">Tạo phiên mới</a></p>
<form method="post" action="/reset"><button>Xóa trạng thái (phiên, CCCD đã gắn, lần thử, khóa)</button></form>
</body>
</html>
''';
}

Future<Map<String, Object?>?> _readJson(HttpRequest request) async {
  final body = await utf8.decoder.bind(request).join();
  try {
    final json = jsonDecode(body);
    return json is Map<String, Object?> ? json : null;
  } on FormatException {
    return null;
  }
}

/// Lỗi theo dạng chung của backend (docs/auth.md).
Future<void> _error(HttpRequest request, int status, String message) => _send(
  request,
  status,
  ContentType.json,
  jsonEncode({
    'status': status,
    'error': _reasonPhrase(status),
    'message': message,
    'path': request.uri.path,
    'timestamp': DateTime.now().toUtc().toIso8601String(),
  }),
);

String _reasonPhrase(int status) => switch (status) {
  HttpStatus.badRequest => 'Bad Request',
  HttpStatus.unauthorized => 'Unauthorized',
  HttpStatus.notFound => 'Not Found',
  HttpStatus.methodNotAllowed => 'Method Not Allowed',
  _ => 'Internal Server Error',
};

Future<void> _send(HttpRequest request, int status, ContentType type, String body) async {
  request.response
    ..statusCode = status
    ..headers.contentType = type
    ..write(body);
  await request.response.close();
}

void _log(String sessionId, String message) {
  final short = sessionId.length <= 14 ? sessionId : '${sessionId.substring(0, 14)}…';
  stdout.writeln('[${_time()}] phiên $short $message');
}

String _randomHex(int bytes) =>
    List.generate(bytes, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

String _time([DateTime? time]) {
  final t = (time ?? DateTime.now()).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}
