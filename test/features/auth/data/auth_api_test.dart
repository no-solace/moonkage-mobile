import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/network/api_endpoints.dart';
import 'package:moonkage_verify/features/auth/data/auth_api.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late AuthApi api;

  setUp(() {
    dio = _MockDio();
    api = AuthApi(dio);
  });

  test('parse token và fullName ở root object', () async {
    when(
      () => dio.post<Object?>(
        ApiEndpoints.login,
        data: {'username': 'an', 'password': '123'},
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ApiEndpoints.login),
        data: {'token': 'jwt-123', 'fullName': 'Nguyen An'},
        statusCode: 200,
      ),
    );

    final session = await api.login(username: 'an', password: '123');

    expect(session.token, 'jwt-123');
    expect(session.fullName, 'Nguyen An');
  });

  test('parse accessToken và envelope data từ backend', () async {
    when(
      () => dio.post<Object?>(
        ApiEndpoints.login,
        data: {'username': 'an', 'password': '123'},
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ApiEndpoints.login),
        data: {
          'data': {'accessToken': 'jwt-456', 'name': 'Le An'},
        },
        statusCode: 200,
      ),
    );

    final session = await api.login(username: 'an', password: '123');

    expect(session.token, 'jwt-456');
    expect(session.fullName, 'Le An');
  });

  test('fallback fullName về username nếu backend không trả fullName', () async {
    when(
      () => dio.post<Object?>(
        ApiEndpoints.login,
        data: {'username': 'an@test.com', 'password': '123'},
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ApiEndpoints.login),
        data: {'token': 'jwt-789'},
        statusCode: 200,
      ),
    );

    final session = await api.login(username: 'an@test.com', password: '123');

    expect(session.token, 'jwt-789');
    expect(session.fullName, 'an@test.com');
  });

  test('ném InvalidResponseFailure nếu không có token', () async {
    when(
      () => dio.post<Object?>(
        ApiEndpoints.login,
        data: {'username': 'an', 'password': '123'},
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(path: ApiEndpoints.login),
        data: {'status': 'ok'},
        statusCode: 200,
      ),
    );

    expect(
      () => api.login(username: 'an', password: '123'),
      throwsA(isA<InvalidResponseFailure>()),
    );
  });
}
