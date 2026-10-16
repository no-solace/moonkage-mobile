import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/network/dio_failure.dart';
import 'package:moonkage_verify/core/network/dio_provider.dart';

final authApiProvider = Provider<AuthApi>((ref) => AuthApi(ref.watch(dioProvider)));

/// identity-service `/api/auth` (docs/auth.md).
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  /// `username` là email hoặc số điện thoại. Sai thông tin thì ném [UnauthorizedFailure];
  /// tài khoản chưa kích hoạt hoặc bị khóa thì ném [ServerFailure] kèm câu của máy chủ.
  Future<AuthSession> login({required String username, required String password}) async {
    final Object? body;
    try {
      final response = await _dio.post<Object?>(
        '/identity-service/api/auth/login',
        data: {'username': username, 'password': password},
      );
      body = response.data;
    } on DioException catch (e) {
      throw failureFromDio(e);
    }

    final token = body is Map<String, Object?> ? body['token'] : null;
    if (body is! Map<String, Object?> || token is! String || token.isEmpty) {
      throw const InvalidResponseFailure();
    }
    final fullName = body['fullName'];
    return AuthSession(token: token, fullName: fullName is String ? fullName : username);
  }
}
