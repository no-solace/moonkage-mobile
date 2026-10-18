/// Cấu hình build, đọc từ `--dart-define-from-file=env/<môi trường>.json`.
///
/// URL máy chủ chỉ lấy từ đây, không đọc từ QR và không cho người dùng nhập.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const nfcTransportPublicKey = String.fromEnvironment('NFC_TRANSPORT_PUBLIC_KEY');
  static const nfcTransportKeyId = String.fromEnvironment('NFC_TRANSPORT_KEY_ID');

  /// Sai thì app dừng ở màn lỗi cấu hình, không dùng URL mặc định.
  static bool get isValid {
    final uri = Uri.tryParse(apiBaseUrl);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }
}
