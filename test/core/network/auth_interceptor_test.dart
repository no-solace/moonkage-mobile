import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/network/dio_provider.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  late ProviderContainer container;
  late FakeHttpAdapter adapter;
  late Dio dio;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    adapter = FakeHttpAdapter(body: {'ok': true});
    dio = container.read(dioProvider)
      ..options.baseUrl = 'http://mock'
      ..httpClientAdapter = adapter;
  });

  void signIn() => container
      .read(sessionProvider.notifier)
      .signIn(const AuthSession(token: 'jwt-abc', fullName: 'Nguyen Van An'));

  test('đã đăng nhập thì gắn Bearer token', () async {
    signIn();
    await dio.get<Object?>('/x');
    expect(adapter.lastRequest?.headers['Authorization'], 'Bearer jwt-abc');
  });

  test('chưa đăng nhập thì không gắn header', () async {
    await dio.get<Object?>('/x');
    expect(adapter.lastRequest?.headers.containsKey('Authorization'), isFalse);
  });

  test('token bị từ chối (401) thì đăng xuất', () async {
    signIn();
    adapter.statusCode = 401;
    await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));
    expect(container.read(sessionProvider), isNull);
  });

  test('lỗi khác 401 thì giữ phiên đăng nhập', () async {
    signIn();
    adapter.statusCode = 500;
    await expectLater(dio.get<Object?>('/x'), throwsA(isA<DioException>()));
    expect(container.read(sessionProvider), isNotNull);
  });
}
