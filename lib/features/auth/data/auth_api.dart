import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/network/api_endpoints.dart';
import 'package:moonkage_verify/core/network/dio_failure.dart';
import 'package:moonkage_verify/core/network/dio_provider.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));

/// identity-service [ApiEndpoints.login] (docs/auth.md).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `username` là email hoặc số điện thoại. Sai thông tin thì ném [UnauthorizedFailure];
  /// tài khoản chưa kích hoạt hoặc bị khóa thì ném [ServerFailure] kèm câu của máy chủ.
  Future<AuthSession> login({required String username, required String password}) async {
    final Object? body;
    try {
      final response = await _dio.post<Object?>(
        ApiEndpoints.login,
        data: {'username': username, 'password': password},
      );
      body = response.data;
    } on DioException catch (e) {
      throw failureFromDio(e);
    }

    final Map<String, Object?>? map;
    if (body is Map<String, Object?>) {
      final nested = body['data'] ?? body['result'];
      map = nested is Map<String, Object?> ? nested : body;
    } else {
      map = null;
    }

    final token = map?['token'] ?? map?['accessToken'];
    if (token is! String || token.trim().isEmpty) {
      throw const InvalidResponseFailure();
    }
    final fullName = map?['fullName'] ?? map?['fullname'] ?? map?['name'];
    return AuthSession(
      token: token.trim(),
      fullName: fullName is String && fullName.trim().isNotEmpty ? fullName.trim() : username,
    );
  }
}
