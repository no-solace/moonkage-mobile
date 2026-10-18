import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/auth/token_storage.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/features/auth/data/auth_api.dart';
import 'package:moonkage_verify/features/auth/presentation/login_notifier.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _FakeTokenStorage implements TokenStorage {
  String? token;
  String? fullName;

  @override
  Future<void> saveSession({required String token, required String fullName}) async {
    this.token = token;
    this.fullName = fullName;
  }

  @override
  Future<AuthSession?> readSession() async {
    if (token == null) return null;
    return AuthSession(token: token!, fullName: fullName ?? '');
  }

  @override
  Future<void> clearSession() async {
    token = null;
    fullName = null;
  }
}

void main() {
  late _MockAuthApi api;
  late _FakeTokenStorage storage;
  late ProviderContainer container;

  setUp(() {
    api = _MockAuthApi();
    storage = _FakeTokenStorage();
    container = ProviderContainer(
      overrides: [
        authApiProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    // Giữ provider autoDispose sống suốt test.
    container.listen(loginProvider, (_, _) {});
  });

  LoginNotifier notifier() => container.read(loginProvider.notifier);

  test('đăng nhập đúng thì lưu phiên, bỏ khoảng trắng ở username', () async {
    when(
      () => api.login(username: 'an@example.com', password: 'secret'),
    ).thenAnswer((_) async => const AuthSession(token: 'jwt', fullName: 'Nguyen Van An'));

    await notifier().login(username: '  an@example.com ', password: 'secret');

    expect(container.read(sessionProvider)?.token, 'jwt');
    expect(storage.token, 'jwt');
    expect(container.read(loginProvider).failure, isNull);
  });

  test('đăng nhập với rememberMe=false thì không lưu storage', () async {
    when(
      () => api.login(username: 'an@example.com', password: 'secret'),
    ).thenAnswer((_) async => const AuthSession(token: 'jwt', fullName: 'Nguyen Van An'));

    await notifier().login(username: 'an@example.com', password: 'secret', rememberMe: false);

    expect(container.read(sessionProvider)?.token, 'jwt');
    expect(storage.token, isNull);
  });

  test('sai thông tin thì báo lỗi và không lưu phiên', () async {
    when(
      () => api.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const UnauthorizedFailure());

    await notifier().login(username: 'an@example.com', password: 'sai');

    expect(container.read(sessionProvider), isNull);
    expect(storage.token, isNull);
    expect(container.read(loginProvider).failure, isA<UnauthorizedFailure>());
    expect(container.read(loginProvider).submitting, isFalse);
  });

  test('clearError xóa failure đang có', () async {
    when(
      () => api.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenThrow(const UnauthorizedFailure());

    await notifier().login(username: 'an@example.com', password: 'sai');
    expect(container.read(loginProvider).failure, isNotNull);

    notifier().clearError();
    expect(container.read(loginProvider).failure, isNull);
  });
}
