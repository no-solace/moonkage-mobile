/// identity-service bọc mọi response công khai trong `ApiResponse<T>`:
/// `{status, code, message, data, timestamp}` (Software Design 5.1 quy tắc 8).
/// Trả về `data` khi có; nếu body không bọc (mock server, bản backend cũ) thì trả nguyên body.
Object? apiPayload(Object? body) {
  if (body is Map<String, Object?>) {
    final data = body['data'];
    if (data is Map<String, Object?>) return data;
  }
  return body;
}
