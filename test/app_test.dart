import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/app.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/auth/presentation/login_screen.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

class _MockNfcReader extends Mock implements NfcReader {}

void main() {
  late _MockNfcReader nfcReader;

  setUp(() {
    nfcReader = _MockNfcReader();
    when(() => nfcReader.ensureSessionStarted(force: any(named: 'force'))).thenAnswer((_) async {});
    when(() => nfcReader.stop()).thenAnswer((_) async {});
  });

  testWidgets('thiếu API_BASE_URL thì dừng ở màn lỗi cấu hình', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nfcReaderProvider.overrideWithValue(nfcReader)],
        child: const MoonkageVerifyApp(configValid: false),
      ),
    );

    expect(find.text(Strings.configErrorTitle), findsOneWidget);
    expect(find.text(Strings.configErrorBody), findsOneWidget);
  });

  testWidgets('chưa đăng nhập thì mở màn đăng nhập và kích hoạt Ambient Shield', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [nfcReaderProvider.overrideWithValue(nfcReader)],
        child: const MoonkageVerifyApp(configValid: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    verify(() => nfcReader.ensureSessionStarted(force: any(named: 'force')))
        .called(greaterThanOrEqualTo(1));
  });
}
