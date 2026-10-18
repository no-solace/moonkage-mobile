/// `reasonCode` máy chủ trả khi từ chối xác minh.
///
/// Đây là chỗ duy nhất ánh xạ chuỗi sang enum.
enum ReasonCode {
  sessionExpired('SESSION_EXPIRED'),
  sessionUsed('SESSION_USED'),

  /// QR là phiên của tài khoản khác với tài khoản đang đăng nhập trên app.
  sessionNotOwned('SESSION_NOT_OWNED'),
  locked('LOCKED'),
  badFormat('BAD_FORMAT'),
  cardExpired('CARD_EXPIRED'),
  idAlreadyLinked('ID_ALREADY_LINKED'),

  /// Mã máy chủ mới thêm mà app chưa biết, hoặc thiếu mã.
  unknown('');

  const ReasonCode(this.code);

  final String code;

  static ReasonCode fromCode(String? code) =>
      values.firstWhere((r) => r != unknown && r.code == code, orElse: () => unknown);
}
