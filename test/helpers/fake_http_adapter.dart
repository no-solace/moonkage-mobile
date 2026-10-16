import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Trả về một phản hồi cố định và ghi lại request cuối, thay cho mạng thật.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter({this.statusCode = 200, this.body});

  int statusCode;
  Object? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
