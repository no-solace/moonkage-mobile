import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/features/verify/data/identity_card_json.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/data/verify_api.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';

import '../../../helpers/card_fixtures.dart';
import '../../../helpers/fake_http_adapter.dart';

void main() {
  const sessionId = '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c';
  late FakeHttpAdapter adapter;
  late VerifyApi api;

  setUp(() {
    adapter = FakeHttpAdapter();
    api = VerifyApi(Dio(BaseOptions(baseUrl: 'http://mock'))..httpClientAdapter = adapter);
  });

  final request = SubmitCardRequest(card: sampleCard, appVersion: '1.0.0+1');

  test('JSON gửi máy chủ dùng camelCase, ngày yyyy-MM-dd', () {
    final json = request.toJson();
    expect(json['idNumber'], '000000000001');
    expect(json['dateOfBirth'], '1990-01-01');
    expect(json['sex'], 'MALE');
    expect(json['placeOfResidence'], startsWith('So 1'));
    expect(json['appVersion'], '1.0.0+1');
  });

  test('gửi thẻ: PENDING_CONFIRMATION trả về thông tin máy chủ đã lưu tạm', () async {
    adapter.body = {
      'status': 'PENDING_CONFIRMATION',
      'card': IdentityCardJson.toJson(sampleCard),
      'expiresAt': '2026-10-16T08:15:00Z',
    };

    final outcome = await api.submitCard(sessionId, request);

    expect(adapter.lastRequest?.path, '/identity-service/api/nfc-sessions/$sessionId/card');
    final pending = outcome as PendingConfirmation;
    expect(pending.card.fullName, 'NGUYEN VAN AN');
    expect(pending.card.placeOfResidence, startsWith('So 1'));
    expect(pending.expiresAt, DateTime.utc(2026, 10, 16, 8, 15));
  });

  test('từ chối kèm mã 4xx vẫn đọc được reasonCode', () async {
    adapter
      ..statusCode = 409
      ..body = {'status': 'REJECTED', 'reasonCode': 'ID_ALREADY_LINKED', 'attemptsLeft': 3};

    final outcome = await api.submitCard(sessionId, request) as Rejected;

    expect(outcome.reason, ReasonCode.idAlreadyLinked);
    expect(outcome.attemptsLeft, 3);
  });

  test('xác nhận: VERIFIED', () async {
    adapter.body = {'status': 'VERIFIED'};
    expect(await api.confirm(sessionId), isA<Verified>());
    expect(adapter.lastRequest?.path, '/identity-service/api/nfc-sessions/$sessionId/confirm');
  });

  test('401 thì ném UnauthorizedFailure', () async {
    adapter
      ..statusCode = 401
      ..body = {'status': 401, 'error': 'Unauthorized', 'message': 'Token hết hạn'};
    expect(api.confirm(sessionId), throwsA(isA<UnauthorizedFailure>()));
  });

  test('lỗi chung của backend thì ném ServerFailure kèm message', () async {
    adapter
      ..statusCode = 400
      ..body = {'status': 400, 'error': 'Bad Request', 'message': 'Phiên không tồn tại'};
    await expectLater(
      api.confirm(sessionId),
      throwsA(isA<ServerFailure>().having((f) => f.message, 'message', 'Phiên không tồn tại')),
    );
  });

  test('phản hồi sai dạng thì ném InvalidResponseFailure', () async {
    adapter.body = {'status': 'PENDING_CONFIRMATION'};
    expect(api.submitCard(sessionId, request), throwsA(isA<InvalidResponseFailure>()));
  });

  test('hủy gọi DELETE .../card', () async {
    adapter.statusCode = 204;
    await api.discard(sessionId);
    expect(adapter.lastRequest?.method, 'DELETE');
    expect(adapter.lastRequest?.path, '/identity-service/api/nfc-sessions/$sessionId/card');
  });
}
