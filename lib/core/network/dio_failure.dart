import 'package:dio/dio.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';

/// Đổi `DioException` sang lỗi của app để `presentation` không phụ thuộc Dio.
AppFailure failureFromDio(DioException e) => switch (e.type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.transformTimeout => const TimeoutFailure(),
  DioExceptionType.badResponse when e.response?.statusCode == 401 => const UnauthorizedFailure(),
  DioExceptionType.badResponse => ServerFailure(
    statusCode: e.response?.statusCode,
    message: _serverMessage(e.response?.data),
  ),
  DioExceptionType.badCertificate ||
  DioExceptionType.cancel ||
  DioExceptionType.connectionError ||
  DioExceptionType.unknown => const NetworkFailure(),
};

/// Body lỗi chung của backend: `{status, error, message, path, timestamp}` (docs/auth.md).
String? _serverMessage(Object? body) {
  if (body is! Map<String, Object?>) return null;
  final message = body['message'];
  return message is String && message.isNotEmpty ? message : null;
}
