import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/core/network/api_endpoints.dart';

void main() {
  const sessionId = '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c';

  group('ApiEndpoints', () {
    test('tiền tố identityService đúng chuẩn gateway D-1, D-18', () {
      expect(ApiEndpoints.identityService, '/identity-service/api');
    });

    test('endpoint đăng nhập auth/login đúng định dạng', () {
      expect(ApiEndpoints.login, '/identity-service/api/auth/login');
    });

    test('nfcSession trả về đúng đường dẫn gốc của phiên', () {
      expect(
        ApiEndpoints.nfcSession(sessionId),
        '/identity-service/api/nfc/sessions/$sessionId',
      );
    });

    test('nfcSessionCard trả về đúng endpoint nộp thẻ kèm mã hóa tham số', () {
      expect(
        ApiEndpoints.nfcSessionCard(sessionId),
        '/identity-service/api/nfc/sessions/$sessionId/card',
      );

      // Mã hóa ký tự đặc biệt nếu có
      expect(
        ApiEndpoints.nfcSessionCard('session/with/slashes'),
        '/identity-service/api/nfc/sessions/session%2Fwith%2Fslashes/card',
      );
    });
  });
}
