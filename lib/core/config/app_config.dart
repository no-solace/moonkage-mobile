/// Cấu hình build, đọc từ `--dart-define-from-file=env/<môi trường>.json`.
///
/// URL máy chủ chỉ lấy từ đây, không đọc từ QR và không cho người dùng nhập.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const nfcTransportPublicKey = String.fromEnvironment('NFC_TRANSPORT_PUBLIC_KEY');
  static const nfcTransportKeyId = String.fromEnvironment('NFC_TRANSPORT_KEY_ID');

  /// Chỉ bật cho mock server (`env/mock.json`): mã hóa bằng khóa demo thay cho khóa của identity-service.
  static const useDemoNfcKey = bool.fromEnvironment('NFC_USE_DEMO_KEY');

  /// Sai thì app dừng ở màn lỗi cấu hình, không dùng URL mặc định.
  /// Thiếu khóa công khai mà không bật khóa demo cũng là sai: mọi thẻ gửi lên sẽ bị BAD_FORMAT và bị đếm.
  static bool get isValid {
    final uri = Uri.tryParse(apiBaseUrl);
    final validUrl =
        uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    return validUrl && (nfcTransportPublicKey.trim().isNotEmpty || useDemoNfcKey);
  }
}
