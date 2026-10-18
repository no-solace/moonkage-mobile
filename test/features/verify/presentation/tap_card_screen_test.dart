import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/strings.dart';
import 'package:moonkage_verify/features/verify/presentation/screens/tap_card_screen.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

class _MockNfcReader extends Mock implements NfcReader {}

class _TestVerifyFlowNotifier extends VerifyFlowNotifier {
  _TestVerifyFlowNotifier(this._initialState);

  final VerifyFlowState _initialState;

  @override
  VerifyFlowState build() => _initialState;

  bool readCardCalled = false;

  @override
  Future<void> readCard() async {
    readCardCalled = true;
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
    return ProviderScope(
      overrides: [
        verifyFlowProvider.overrideWith(() => notifier),
        nfcReaderProvider.overrideWithValue(reader),
      ],
      child: const MaterialApp(
        home: TapCardScreen(),
      ),
    );
  }

  testWidgets('hiển thị hoạt ảnh sóng NFC và các chỉ dẫn khi đang đọc thẻ (ReadingCard)', (
    tester,
  ) async {
    final notifier = _TestVerifyFlowNotifier(const ReadingCard(sessionId: sessionId));

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(Strings.tapCardTitle), findsOneWidget);
    expect(find.text(Strings.tapCardHint), findsOneWidget);
    expect(find.text(Strings.tapCardPositionHint), findsOneWidget);
    expect(find.text(Strings.tapCardSubHint), findsOneWidget);
    expect(find.byIcon(Icons.contactless_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('hiển thị cảnh báo lỗi và nút Thử lại khi sai loại thẻ (wrongCard)', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      const AwaitingCard(sessionId: sessionId, issue: CardIssue.wrongCard),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(Strings.wrongCard), findsOneWidget);
    expect(find.text(Strings.retry), findsOneWidget);
    expect(find.byIcon(Icons.contactless_outlined), findsOneWidget);

    await tester.tap(find.text(Strings.retry));
    await tester.pump();
    expect(notifier.readCardCalled, isTrue);
  });

  testWidgets('hiển thị lỗi đọc thất bại khi trượt thẻ (readFailed)', (tester) async {
    final notifier = _TestVerifyFlowNotifier(
      const AwaitingCard(sessionId: sessionId, issue: CardIssue.readFailed),
    );

    await tester.pumpWidget(createSubject(notifier));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(Strings.cardReadFailed), findsOneWidget);
    expect(find.text(Strings.retry), findsOneWidget);
  });
}
