/// Lỗi kỹ thuật khi gọi máy chủ. Lý do nghiệp vụ (`reasonCode`) không nằm ở đây.
sealed class AppFailure implements Exception {
  const AppFailure();
}

/// Không kết nối được máy chủ (mất mạng, sai IP LAN, tunnel tắt).
final class NetworkFailure extends AppFailure {
  const NetworkFailure();
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure();
}

/// 401: sai thông tin đăng nhập, hoặc token hết hạn (khi đó app tự đăng xuất).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure();
}

/// Máy chủ trả mã HTTP lỗi. [message] là câu tiếng Việt máy chủ gửi kèm, nếu có.
final class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode, this.message});

  final int? statusCode;
  final String? message;
}

/// Phản hồi không đúng dạng hợp đồng API.
final class InvalidResponseFailure extends AppFailure {
  const InvalidResponseFailure();
}
