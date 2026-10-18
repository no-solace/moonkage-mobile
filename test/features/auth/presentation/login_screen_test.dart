import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/token_storage.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/auth/data/auth_api.dart';
import 'package:moonkage_verify/features/auth/presentation/login_screen.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _FakeTokenStorage implements TokenStorage {
  @override
  Future<void> saveSession({required String token, required String fullName}) async {}

  @override
  Future<AuthSession?> readSession() async => null;

  @override
  Future<void> clearSession() async {}
}

void main() {
  late _MockAuthApi api;
  late _FakeTokenStorage storage;

  setUp(() {
    api = _MockAuthApi();
    storage = _FakeTokenStorage();
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        authApiProvider.overrideWithValue(api),
        tokenStorageProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );
  }

  testWidgets('hiển thị đầy đủ form đăng nhập và checkbox Ghi nhớ đăng nhập', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.text(Strings.usernameLabel), findsOneWidget);
    expect(find.text(Strings.passwordLabel), findsOneWidget);
    expect(find.text(Strings.rememberMe), findsOneWidget);
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.widgetWithText(FilledButton, Strings.login), findsOneWidget);

    // Mặc định Remember Me là true
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('bật/tắt ẩn hiện mật khẩu khi bấm icon con mắt', (tester) async {
    await tester.pumpWidget(buildScreen());

    // Ban đầu mật khẩu ẩn
    final passwordFieldFinder = find.byType(TextField).at(1);
    var passwordWidget = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordWidget.obscureText, isTrue);

    // Bấm nút con mắt
    final eyeButton = find.byTooltip('Hiện mật khẩu');
    expect(eyeButton, findsOneWidget);
    await tester.tap(eyeButton);
    await tester.pump();

    // Mật khẩu hiện rõ
    passwordWidget = tester.widget<TextField>(passwordFieldFinder);
    expect(passwordWidget.obscureText, isFalse);
  });

  testWidgets('báo lỗi khi để trống tài khoản hoặc mật khẩu', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.widgetWithText(FilledButton, Strings.login));
    await tester.pump();

    expect(find.text(Strings.requiredField), findsNWidgets(2));
  });
}
