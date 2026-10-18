import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/core/network/api_endpoints.dart';
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

  final request = SubmitCardRequest(
    card: sampleCard,
    encryptedFields: 'mock.jwe.token',
    appVersion: '1.0.0+1',
  );

  test('JSON gửi máy chủ bọc 3 trường nhạy cảm trong encryptedFields (D-17)', () {
    final json = request.toJson();
    expect(json['idNumber'], isNull);
    expect(json['dateOfBirth'], isNull);
    expect(json['placeOfResidence'], isNull);
    expect(json['encryptedFields'], 'mock.jwe.token');
    expect(json['fullName'], 'NGUYEN VAN AN');
    expect(json['sex'], 'MALE');
    expect(json['dateOfIssue'], '2024-01-01');
    expect(json['dateOfExpiry'], '2030-01-01');
    expect(json['appVersion'], '1.0.0+1');
  });

  test('gửi thẻ thành công trả về VERIFIED trực tiếp (D-20)', () async {
    adapter.body = {'status': 'VERIFIED'};

    final outcome = await api.submitCard(sessionId, request);

    expect(adapter.lastRequest?.path, ApiEndpoints.nfcSessionCard(sessionId));
    expect(outcome, isA<Verified>());
  });

  test('từ chối kèm mã 4xx vẫn đọc được reasonCode', () async {
    adapter
      ..statusCode = 409
      ..body = {'status': 'REJECTED', 'reasonCode': 'ID_ALREADY_LINKED', 'attemptsLeft': 3};

    final outcome = await api.submitCard(sessionId, request) as Rejected;

    expect(outcome.reason, ReasonCode.idAlreadyLinked);
    expect(outcome.attemptsLeft, 3);
  });

  test('401 thì ném UnauthorizedFailure', () async {
    adapter
      ..statusCode = 401
      ..body = {'status': 401, 'error': 'Unauthorized', 'message': 'Token hết hạn'};
    expect(api.submitCard(sessionId, request), throwsA(isA<UnauthorizedFailure>()));
  });

  test('lỗi chung của backend thì ném ServerFailure kèm message', () async {
    adapter
      ..statusCode = 400
      ..body = {'status': 400, 'error': 'Bad Request', 'message': 'Phiên không tồn tại'};
    await expectLater(
      api.submitCard(sessionId, request),
      throwsA(isA<ServerFailure>().having((f) => f.message, 'message', 'Phiên không tồn tại')),
    );
  });

  test('phản hồi sai dạng thì ném InvalidResponseFailure', () async {
    adapter.body = {'status': 'UNKNOWN_STATUS'};
    expect(api.submitCard(sessionId, request), throwsA(isA<InvalidResponseFailure>()));
  });

  group('ApiResponse<T> của identity-service', () {
    Map<String, Object?> wrapped(Map<String, Object?> data) => {
      'status': 200,
      'code': 'SUCCESS',
      'message': 'OK',
      'data': data,
      'timestamp': '2026-10-19T03:00:00Z',
    };

    test('gửi thẻ: kết quả nằm trong data', () async {
      adapter.body = wrapped({'status': 'REJECTED', 'reasonCode': 'BAD_FORMAT', 'attemptsLeft': 4});

      final outcome = await api.submitCard(sessionId, request) as Rejected;

      expect(outcome.reason, ReasonCode.badFormat);
      expect(outcome.attemptsLeft, 4);
    });

    test('gửi thẻ: VERIFIED trong data', () async {
      adapter.body = wrapped({'status': 'VERIFIED'});
      expect(await api.submitCard(sessionId, request), isA<Verified>());
    });

    test('checkSession: đọc status trong data', () async {
      adapter.body = wrapped({'sessionId': sessionId, 'status': 'PENDING'});
      await expectLater(api.checkSession(sessionId), completes);
    });

    test('lỗi bọc (data: null, status là số) thì ném ServerFailure kèm message', () async {
      adapter
        ..statusCode = 403
        ..body = {
          'status': 403,
          'code': 'NFC_002',
          'message': 'Xác minh NFC đang tạm khóa',
          'data': null,
          'path': '/api/nfc-sessions/x/card',
        };
      await expectLater(
        api.submitCard(sessionId, request),
        throwsA(isA<ServerFailure>().having((f) => f.message, 'message', 'Xác minh NFC đang tạm khóa')),
      );
    });
  });

  group('checkSession', () {
    test('phiên ACTIVE thì hoàn thành bình thường', () async {
      adapter.body = {'sessionId': sessionId, 'status': 'ACTIVE'};
      await expectLater(api.checkSession(sessionId), completes);
    });

    test('404 hoặc 410 ném ServerFailure(410)', () async {
      adapter.statusCode = 404;
      await expectLater(
        api.checkSession(sessionId),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 410)),
      );
    });

    test('403 ném ServerFailure(403)', () async {
      adapter.statusCode = 403;
      await expectLater(
        api.checkSession(sessionId),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 403)),
      );
    });

    test('body trả về EXPIRED ném ServerFailure(410)', () async {
      adapter.body = {'sessionId': sessionId, 'status': 'EXPIRED'};
      await expectLater(
        api.checkSession(sessionId),
        throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'statusCode', 410)),
      );
    });
  });
}
