import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/config/app_version_provider.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/data/verify_api.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

import '../../../helpers/card_fixtures.dart';

class _MockVerifyApi extends Mock implements VerifyApi {}

class _MockNfcReader extends Mock implements NfcReader {}

void main() {
  const sessionId = '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c';
  const qr = 'moonkage-verify:v1:$sessionId';

  late _MockVerifyApi api;
  late _MockNfcReader reader;
  late ProviderContainer container;

  VerifyFlowNotifier notifier() => container.read(verifyFlowProvider.notifier);
  VerifyFlowState state() => container.read(verifyFlowProvider);

  setUpAll(() {
    registerFallbackValue(SubmitCardRequest(card: sampleCard, appVersion: ''));
  });

  setUp(() {
    api = _MockVerifyApi();
    reader = _MockNfcReader();
    container = ProviderContainer(
      overrides: [
        verifyApiProvider.overrideWithValue(api),
        nfcReaderProvider.overrideWithValue(reader),
        appVersionProvider.overrideWith((ref) async => '1.0.0+1'),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .signIn(const AuthSession(token: 'jwt', fullName: 'Nguyen Van An'));
  });

  void cardReturns(List<String> records) =>
      when(() => reader.readTextRecords()).thenAnswer((_) async => records);

  void submitReturns(VerifyOutcome outcome) =>
      when(() => api.submitCard(any(), any())).thenAnswer((_) async => outcome);

  Future<void> scanAndTap() async {
    notifier().acceptQr(qr);
    await notifier().readCard();
  }

  test('QR sai dạng thì không nhận và vẫn chờ QR', () {
    expect(notifier().acceptQr('https://example.com'), isFalse);
    expect(state(), isA<AwaitingQr>());
  });

  test('thẻ hợp lệ thì gửi các trường đã đọc và chờ người dùng xác nhận', () async {
    cardReturns(['other', sampleCardText()]);
    submitReturns(PendingConfirmation(card: sampleCard));

    await scanAndTap();

    final sent =
        verify(() => api.submitCard(sessionId, captureAny())).captured.single as SubmitCardRequest;
    expect(sent.card.idNumber, '000000000001');
    expect(sent.card.fullName, 'NGUYEN VAN AN');
    expect(sent.appVersion, '1.0.0+1');
    final awaiting = state() as AwaitingConfirmation;
    expect(awaiting.sessionId, sessionId);
    expect(awaiting.card.placeOfBirth, 'Tinh Lam Dong');
  });

  test('bấm Lưu thì gọi confirm và hiện kết quả', () async {
    cardReturns([sampleCardText()]);
    submitReturns(PendingConfirmation(card: sampleCard));
    when(() => api.confirm(sessionId)).thenAnswer((_) async => const Verified());

    await scanAndTap();
    await notifier().confirm();

    expect((state() as Completed).outcome, isA<Verified>());
  });

  test('Lưu bị lỗi mạng thì giữ thông tin để bấm lại', () async {
    cardReturns([sampleCardText()]);
    submitReturns(PendingConfirmation(card: sampleCard));
    when(() => api.confirm(sessionId)).thenThrow(const NetworkFailure());

    await scanAndTap();
    await notifier().confirm();

    final awaiting = state() as AwaitingConfirmation;
    expect(awaiting.failure, isA<NetworkFailure>());
    expect(awaiting.saving, isFalse);
  });

  test('bấm Hủy thì bỏ thông tin và nhờ máy chủ xóa bản lưu tạm', () async {
    cardReturns([sampleCardText()]);
    submitReturns(PendingConfirmation(card: sampleCard));
    when(() => api.discard(sessionId)).thenAnswer((_) async {});

    await scanAndTap();
    await notifier().discard();

    expect(state(), isA<AwaitingQr>());
    verify(() => api.discard(sessionId)).called(1);
  });

  test('thẻ không phải thẻ Moonkage thì báo sai loại thẻ và không gọi máy chủ', () async {
    cardReturns(['https://moonkage.vn']);

    await scanAndTap();

    expect((state() as AwaitingCard).issue, CardIssue.wrongCard);
    verifyNever(() => api.submitCard(any(), any()));
  });

  test('thẻ Moonkage sai trường thì báo sai định dạng và không gọi máy chủ', () async {
    cardReturns([
      sampleCardText({'id_number': '00000000001'}),
    ]);

    await scanAndTap();

    expect((state() as AwaitingCard).issue, CardIssue.badFormat);
    verifyNever(() => api.submitCard(any(), any()));
  });

  test('đọc thẻ lỗi thì cho chạm lại', () async {
    when(() => reader.readTextRecords()).thenThrow(const NfcReadException());

    await scanAndTap();

    expect((state() as AwaitingCard).issue, CardIssue.readFailed);
  });

  test('máy chủ từ chối thì hiện reasonCode', () async {
    cardReturns([sampleCardText()]);
    submitReturns(const Rejected(reason: ReasonCode.sessionNotOwned));

    await scanAndTap();

    expect(((state() as Completed).outcome as Rejected).reason, ReasonCode.sessionNotOwned);
  });

  test('mất mạng khi gửi thì giữ phiên và cho chạm lại', () async {
    cardReturns([sampleCardText()]);
    when(() => api.submitCard(any(), any())).thenThrow(const NetworkFailure());

    await scanAndTap();

    final awaiting = state() as AwaitingCard;
    expect(awaiting.sessionId, sessionId);
    expect(awaiting.failure, isA<NetworkFailure>());
  });

  test('đăng xuất thì bỏ luồng đang dở, kể cả thông tin thẻ', () async {
    cardReturns([sampleCardText()]);
    submitReturns(PendingConfirmation(card: sampleCard));

    await scanAndTap();
    container.read(sessionProvider.notifier).signOut();

    expect(state(), isA<AwaitingQr>());
  });
}
