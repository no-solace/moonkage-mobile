import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/result_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';
import 'package:moonkage_verify/router.dart';

class _MockNfcReader extends Mock implements NfcReader {}

class _TestVerifyFlowNotifier extends VerifyFlowNotifier {
  _TestVerifyFlowNotifier(this._initialState);

  final VerifyFlowState _initialState;

  @override
  VerifyFlowState build() => _initialState;

  bool resetCalled = false;

  @override
  void reset() {
    resetCalled = true;
  }
}

void main() {
  late _MockNfcReader reader;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    reader = _MockNfcReader();
    when(() => reader.cancel()).thenAnswer((_) async {});
  });

  Widget createSubject(VerifyFlowNotifier notifier) {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(path: '/result', builder: (_, _) => const ResultScreen()),
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

  testWidgets('hiển thị màn hình thành công khi outcome là Verified', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      const Completed(outcome: Verified()),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pumpAndSettle();

    expect(find.text(Strings.resultTitle), findsOneWidget);
    expect(find.text(Strings.verified), findsOneWidget);
    expect(find.text(Strings.verifiedBody), findsOneWidget);
    expect(find.text(Strings.backToWeb), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text(Strings.done));
    await tester.pumpAndSettle();
    expect(notifier.resetCalled, isTrue);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('hiển thị màn hình thất bại khi outcome là Rejected', (tester) async {
    final lockedUntil = DateTime.now().add(const Duration(hours: 1));
    final notifier = _TestVerifyFlowNotifier(
      Completed(
        outcome: Rejected(
          reason: ReasonCode.sessionExpired,
          attemptsLeft: 2,
          lockedUntil: lockedUntil,
        ),
      ),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pumpAndSettle();

    expect(find.text(Strings.resultTitle), findsOneWidget);
    expect(find.text(Strings.rejected), findsOneWidget);
    expect(find.text(Strings.reason(ReasonCode.sessionExpired)), findsOneWidget);
    expect(find.text(Strings.attemptsLeft(2)), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
  });
}
