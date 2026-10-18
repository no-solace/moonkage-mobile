/// Phiên đăng nhập người dùng. Giữ trong bộ nhớ và có thể lưu an toàn qua
/// [TokenStorage] nếu người dùng bật Ghi nhớ đăng nhập.
final class AuthSession {
  const AuthSession({required this.token, required this.fullName});

  /// Access token (JWT) của identity-service.
  final String token;
  final String fullName;
}
