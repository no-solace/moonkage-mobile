import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/app.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('thiếu API_BASE_URL thì dừng ở màn lỗi cấu hình', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoonkageVerifyApp(configValid: false)));

    expect(find.text(Strings.configErrorTitle), findsOneWidget);
    expect(find.text(Strings.configErrorBody), findsOneWidget);
  });

  testWidgets('chưa đăng nhập thì mở màn đăng nhập', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MoonkageVerifyApp(configValid: true)));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
