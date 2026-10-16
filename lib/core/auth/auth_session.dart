/// Phiên đăng nhập. Chỉ giữ trong bộ nhớ: tắt app là phải đăng nhập lại.
final class AuthSession {
  const AuthSession({required this.token, required this.fullName});

  /// Access token (JWT) của identity-service.
  final String token;
  final String fullName;
}
