import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/core/network/api_endpoints.dart';
import 'package:moonkage_verify/core/network/dio_failure.dart';
import 'package:moonkage_verify/core/network/dio_provider.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/data/session_result_response.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';

final verifyApiProvider = Provider<VerifyApi>((ref) => VerifyApi(ref.watch(dioProvider)));

/// Các endpoint phiên xác minh NFC. Cần đăng nhập (Bearer token do `AuthInterceptor` gắn).
class VerifyApi {
  VerifyApi(this._dio);

  final Dio _dio;

  /// Kiểm tra trạng thái phiên xác minh trước khi bước vào màn Chạm thẻ.
  /// Ném [AppFailure] nếu phiên hết hạn, thuộc tài khoản khác hoặc lỗi mạng.
  Future<void> checkSession(String sessionId) async {
    try {
      final response = await _dio.get<Object?>(ApiEndpoints.nfcSession(sessionId));
      final body = response.data;
      if (body is Map<String, Object?>) {
        final status = body['status'];
        if (status is String) {
          final s = status.toUpperCase();
          if (s == 'EXPIRED' || s == 'SESSION_EXPIRED') {
            throw ServerFailure(
              statusCode: 410,
              message: Strings.reason(ReasonCode.sessionExpired),
            );
          }
          if (s == 'USED' || s == 'SESSION_USED') {
            throw ServerFailure(
              statusCode: 409,
              message: Strings.reason(ReasonCode.sessionUsed),
            );
          }
          if (s == 'SESSION_NOT_OWNED') {
            throw ServerFailure(
              statusCode: 403,
              message: Strings.reason(ReasonCode.sessionNotOwned),
            );
          }
        }
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 410) {
        throw ServerFailure(
          statusCode: 410,
          message: Strings.reason(ReasonCode.sessionExpired),
        );
      }
      if (code == 403) {
        throw ServerFailure(
          statusCode: 403,
          message: Strings.reason(ReasonCode.sessionNotOwned),
        );
      }
      if (code == 409) {
        throw ServerFailure(
          statusCode: 409,
          message: Strings.reason(ReasonCode.sessionUsed),
        );
      }
      throw failureFromDio(e);
    }
  }

  /// Gửi thông tin thẻ kèm encryptedFields một lần sau khi người dùng xác nhận (Software Design D-20).
  /// Trả về [Verified] hoặc [Rejected].
  Future<VerifyOutcome> submitCard(String sessionId, SubmitCardRequest request) =>
      _post(ApiEndpoints.nfcSessionCard(sessionId), data: request.toJson());

  /// Ném [AppFailure] khi không có kết quả (mạng, timeout, 401, máy chủ lỗi, phản hồi sai dạng).
  Future<VerifyOutcome> _post(String path, {Object? data}) async {
    Object? body;
    try {
      body = (await _dio.post<Object?>(path, data: data)).data;
    } on DioException catch (e) {
      // Từ chối nghiệp vụ có thể đi kèm mã 4xx; body vẫn là kết quả (`status` dạng chuỗi).
      final errorBody = e.response?.data;
      final isOutcome = errorBody is Map<String, Object?> && errorBody['status'] is String;
      if (e.type != DioExceptionType.badResponse || !isOutcome || e.response?.statusCode == 401) {
        throw failureFromDio(e);
      }
      body = errorBody;
    }

    if (body is! Map<String, Object?>) throw const InvalidResponseFailure();
    try {
      return SessionResultResponse.fromJson(body);
    } on TypeError {
      throw const InvalidResponseFailure();
    } on FormatException {
      throw const InvalidResponseFailure();
    }
  }
}
