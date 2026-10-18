const qrPrefix = 'moonkage-verify:';

// session_id là chuỗi ngẫu nhiên ≥ 128 bit (Software Design 5.1): chấp nhận UUID, base64url, hex.
final _sessionIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');
final _prefixPattern = RegExp(
  r'^moonkage-verify(?::v\d+)?:([A-Za-z0-9_-]{16,128})$',
  caseSensitive: false,
);

/// Nội dung QR trên trang web:
/// - Tiền tố: `moonkage-verify:v1:<session_id>`, `moonkage-verify:v2:<session_id>`
/// - Web URL: `https://.../verify?session=<session_id>` hoặc `https://.../nfc-sessions/<session_id>`
final class SessionQr {
  const SessionQr._(this.sessionId);

  final String sessionId;

  /// Phân tích nội dung QR linh hoạt, không hardcode cố định phiên bản.
  static SessionQr? tryParse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    // 1. Dạng tiền tố: moonkage-verify:v1:<sessionId> hoặc moonkage-verify:<sessionId>
    final prefixMatch = _prefixPattern.firstMatch(value);
    if (prefixMatch != null) {
      final id = prefixMatch.group(1)!;
      return SessionQr._(id);
    }

    // 2. Dạng URL Web
    final uri = Uri.tryParse(value);
    if (uri != null && uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
      final querySession =
          uri.queryParameters['session'] ??
          uri.queryParameters['sessionId'] ??
          uri.queryParameters['id'];
      if (querySession != null && _sessionIdPattern.hasMatch(querySession)) {
        return SessionQr._(querySession);
      }

      final segments = uri.pathSegments;
      if (segments.isNotEmpty) {
        final lastSegment = segments.last;
        if (_sessionIdPattern.hasMatch(lastSegment)) {
          final parent = segments.length >= 2 ? segments[segments.length - 2] : '';
          if (parent == 'nfc-sessions' || parent == 'verify' || parent == 'session') {
            return SessionQr._(lastSegment);
          }
        }
      }
    }

    return null;
  }
}
