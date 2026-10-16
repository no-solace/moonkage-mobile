import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/network/dio_failure.dart';
import 'package:moonkage_verify/core/network/dio_provider.dart';
import 'package:moonkage_verify/features/verify/data/session_result_response.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';

final verifyApiProvider = Provider<VerifyApi>((ref) => VerifyApi(ref.watch(dioProvider)));

/// Các endpoint phiên xác minh NFC. Cần đăng nhập (Bearer token do `AuthInterceptor` gắn).
class VerifyApi {
  VerifyApi(this._dio);

  final Dio _dio;

  static String _sessionPath(String sessionId) =>
      '/identity-service/api/nfc-sessions/${Uri.encodeComponent(sessionId)}';

  /// Gửi thông tin thẻ để máy chủ lưu tạm. Trả về [PendingConfirmation] hoặc [Rejected].
  Future<VerifyOutcome> submitCard(String sessionId, SubmitCardRequest request) =>
      _post('${_sessionPath(sessionId)}/card', data: request.toJson());

  /// Người dùng bấm Lưu: máy chủ ghi thông tin đã lưu tạm vào tài khoản.
  /// Trả về [Verified] hoặc [Rejected].
  Future<VerifyOutcome> confirm(String sessionId) => _post('${_sessionPath(sessionId)}/confirm');

  /// Người dùng bấm Hủy: máy chủ xóa thông tin đã lưu tạm.
  Future<void> discard(String sessionId) async {
    try {
      await _dio.delete<void>('${_sessionPath(sessionId)}/card');
    } on DioException catch (e) {
      throw failureFromDio(e);
    }
  }

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
