import 'package:moonkage_verify/core/config/app_config.dart';

/// Quản lý tập trung toàn bộ endpoint và URL của hệ thống API.
/// Tránh hardcode chuỗi đường dẫn rải rác trong các feature (Auth, Verify,...).
abstract final class ApiEndpoints {
  /// Tiền tố gateway của identity-service (theo quyết định kiến trúc D-1 và D-18).
  static const identityService = '/identity-service/api';

  // --- Auth Endpoints ---
  /// Đăng nhập: `POST /identity-service/api/auth/login`
  static const login = '$identityService/auth/login';

  // --- NFC Verification Endpoints ---
  /// Gốc phiên NFC: `/identity-service/api/nfc-sessions/{sessionId}`
  static String nfcSession(String sessionId) =>
      '$identityService/nfc-sessions/${Uri.encodeComponent(sessionId)}';

  /// Gửi thẻ xác minh: `POST /identity-service/api/nfc-sessions/{sessionId}/card`
  static String nfcSessionCard(String sessionId) => '${nfcSession(sessionId)}/card';

  /// Trả về [Uri] tuyệt đối kết hợp với [AppConfig.apiBaseUrl] khi cần mở URL ngoài hoặc chia sẻ liên kết.
  static Uri resolve(String path) => Uri.parse(AppConfig.apiBaseUrl).resolve(path);
}
