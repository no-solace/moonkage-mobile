const qrPrefix = 'moonkage-verify:v1:';

// session_id là chuỗi ngẫu nhiên ≥ 128 bit (Software Design 5.1): chấp nhận UUID, base64url, hex.
final _sessionIdPattern = RegExp(r'^[A-Za-z0-9_-]{16,128}$');

/// Nội dung QR trên trang web: `moonkage-verify:v1:<session_id>`.
final class SessionQr {
  const SessionQr._(this.sessionId);

  final String sessionId;

  /// Sai tiền tố hoặc `session_id` không hợp lệ thì trả về null; khi đó không gọi API.
  static SessionQr? tryParse(String raw) {
    final value = raw.trim();
    if (!value.startsWith(qrPrefix)) return null;
    final sessionId = value.substring(qrPrefix.length);
    return _sessionIdPattern.hasMatch(sessionId) ? SessionQr._(sessionId) : null;
  }
}
