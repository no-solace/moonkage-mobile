import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/config/app_config.dart';
import 'package:moonkage_verify/core/network/auth_interceptor.dart';

/// Instance `Dio` duy nhất của app. Không thêm interceptor log body (dữ liệu thẻ, mật khẩu).
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    ),
  )..interceptors.add(AuthInterceptor(ref));
  ref.onDispose(dio.close);
  return dio;
});
