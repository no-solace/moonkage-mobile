import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';

/// Gắn `Authorization: Bearer <token>`; token hết hạn (401) thì đăng xuất để router về màn đăng nhập.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._ref);

  final Ref _ref;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _ref.read(sessionProvider)?.token;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final sentToken = err.requestOptions.headers.containsKey('Authorization');
    if (sentToken && err.response?.statusCode == 401) {
      _ref.read(sessionProvider.notifier).signOut();
    }
    handler.next(err);
  }
}
