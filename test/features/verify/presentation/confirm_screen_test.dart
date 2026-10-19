import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/confirm_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:moonkage_verify/router.dart';

import '../../../helpers/card_fixtures.dart';

class _MockNfcReader extends Mock implements NfcReader {}

class _TestVerifyFlowNotifier extends VerifyFlowNotifier {
  _TestVerifyFlowNotifier(this._initialState);

  final VerifyFlowState _initialState;

  @override
  VerifyFlowState build() => _initialState;

  bool confirmCalled = false;
  bool discardCalled = false;

  @override
  Future<void> confirm() async {
    confirmCalled = true;
  }

  @override
  Future<void> discard() async {
    discardCalled = true;
  }
}

void main() {
  const sessionId = 'test-session-123';
  late _MockNfcReader reader;

  setUp(() {
    reader = _MockNfcReader();
    when(() => reader.cancel()).thenAnswer((_) async {});
  });

  Widget createSubject(VerifyFlowNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/confirm',
      routes: [
        GoRoute(path: '/confirm', builder: (_, _) => const ConfirmScreen()),
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const Scaffold(body: Text('HOME')),
        ),
      ],
    );
    return ProviderScope(
      overrides: [
        verifyFlowProvider.overrideWith(() => notifier),
        nfcReaderProvider.overrideWithValue(reader),
      ],
      child: MaterialApp.router(
        routerConfig: router,
      ),
    );
  }

  testWidgets('hiển thị đầy đủ thông tin và mặc định che số CCCD', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      AwaitingConfirmation(sessionId: sessionId, card: sampleCard),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump();

    expect(find.text(Strings.confirmTitle), findsOneWidget);
    expect(find.text(sampleCard.fullName), findsOneWidget);
    expect(find.text(Strings.genderMale), findsOneWidget);
    expect(find.text(sampleCard.nationality), findsOneWidget);

    // Mặc định che 6 số giữa: ví dụ '079 ••• ••• 890'
    final maskedPrefix = sampleCard.idNumber.substring(0, 3);
    final maskedSuffix = sampleCard.idNumber.substring(sampleCard.idNumber.length - 3);
    expect(find.text('$maskedPrefix ••• ••• $maskedSuffix'), findsOneWidget);
    expect(find.text(sampleCard.idNumber), findsNothing);

    // Bấm icon con mắt để hiện toàn bộ số CCCD
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.text(sampleCard.idNumber), findsOneWidget);

    // Bấm lại để che lại
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(find.text('$maskedPrefix ••• ••• $maskedSuffix'), findsOneWidget);
  });

  testWidgets('bấm Hủy gọi discard() và điều hướng', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      AwaitingConfirmation(sessionId: sessionId, card: sampleCard),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump();

    await tester.tap(find.text(Strings.cancel));
    await tester.pumpAndSettle();
    expect(notifier.discardCalled, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('bấm Lưu gọi confirm()', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      AwaitingConfirmation(sessionId: sessionId, card: sampleCard),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump();

    await tester.tap(find.text(Strings.save));
    await tester.pump();
    expect(notifier.confirmCalled, isTrue);
  });

  testWidgets('khi saving = true hiển thị loading overlay', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      AwaitingConfirmation(sessionId: sessionId, card: sampleCard, saving: true),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(Strings.saving), findsWidgets);
  });

  testWidgets('hiển thị thông báo lỗi mạng khi có failure', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      AwaitingConfirmation(
        sessionId: sessionId,
        card: sampleCard,
        failure: const NetworkFailure(),
      ),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump();

    expect(
      find.text(Strings.failure(const NetworkFailure()), skipOffstage: false),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline, skipOffstage: false), findsOneWidget);
  });
}
