import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/auth/token_storage.dart';

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
  late _FakeTokenStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = _FakeTokenStorage();
    container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
  });

  test('signIn với rememberMe=true thì lưu vào storage', () async {
    final notifier = container.read(sessionProvider.notifier);
    const session = AuthSession(token: 'my-token', fullName: 'Nguyen Van An');

    notifier.signIn(session, rememberMe: true);

    expect(container.read(sessionProvider)?.token, 'my-token');
    expect(storage.token, 'my-token');
    expect(storage.fullName, 'Nguyen Van An');
  });

  test('signIn với rememberMe=false thì không lưu và xóa storage cũ', () async {
    storage.token = 'old-token';
    final notifier = container.read(sessionProvider.notifier);
    const session = AuthSession(token: 'my-token', fullName: 'Nguyen Van An');

    notifier.signIn(session, rememberMe: false);

    expect(container.read(sessionProvider)?.token, 'my-token');
    expect(storage.token, isNull);
  });

  test('signOut thì xóa cả state và storage', () async {
    final notifier = container.read(sessionProvider.notifier);
    const session = AuthSession(token: 'my-token', fullName: 'Nguyen Van An');
    notifier.signIn(session, rememberMe: true);

    notifier.signOut();

    expect(container.read(sessionProvider), isNull);
    expect(storage.token, isNull);
  });

  test('nạp initialSession từ provider nếu có', () {
    const initial = AuthSession(token: 'saved-token', fullName: 'Saved User');
    final restoredContainer = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(storage),
        initialSessionProvider.overrideWithValue(initial),
      ],
    );
    addTearDown(restoredContainer.dispose);

    expect(restoredContainer.read(sessionProvider)?.token, 'saved-token');
    expect(restoredContainer.read(sessionProvider)?.fullName, 'Saved User');
  });
}
