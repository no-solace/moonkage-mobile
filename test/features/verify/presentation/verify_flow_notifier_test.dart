import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/config/app_version_provider.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/features/verify/data/card_encryptor.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/data/verify_api.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_notifier.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

import '../../../helpers/card_fixtures.dart';

class _MockVerifyApi extends Mock implements VerifyApi {}

class _MockNfcReader extends Mock implements NfcReader {}

class _MockCardEncryptor extends Mock implements CardEncryptor {}

void main() {
  const sessionId = '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c';
  const qr = 'moonkage-verify:v1:$sessionId';

  late _MockVerifyApi api;
  late _MockNfcReader reader;
  late _MockCardEncryptor encryptor;
  late ProviderContainer container;

  VerifyFlowNotifier notifier() => container.read(verifyFlowProvider.notifier);
  VerifyFlowState state() => container.read(verifyFlowProvider);

  setUpAll(() {
    registerFallbackValue(
      SubmitCardRequest(card: sampleCard, encryptedFields: '', appVersion: ''),
    );
  });

  setUp(() {
    api = _MockVerifyApi();
    reader = _MockNfcReader();
    encryptor = _MockCardEncryptor();
    when(() => reader.ensureSessionStarted(force: any(named: 'force'))).thenAnswer((_) async {});
    when(() => reader.stop()).thenAnswer((_) async {});
    when(() => reader.cancel()).thenAnswer((_) async {});
    when(
      () => encryptor.encryptFields(
        idNumber: any(named: 'idNumber'),
        dateOfBirth: any(named: 'dateOfBirth'),
        placeOfResidence: any(named: 'placeOfResidence'),
      ),
    ).thenAnswer((_) async => 'mock.jwe.token');

    container = ProviderContainer(
      overrides: [
        verifyApiProvider.overrideWithValue(api),
        nfcReaderProvider.overrideWithValue(reader),
        cardEncryptorProvider.overrideWithValue(encryptor),
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

  test('thẻ hợp lệ thì hiện tại máy (AwaitingConfirmation) và CHƯA gọi máy chủ', () async {
    cardReturns(['other', sampleCardText()]);

    await scanAndTap();

    // Không gửi gì lên máy chủ tại thời điểm chạm thẻ (AC-04.4, D-20)
    verifyNever(() => api.submitCard(any(), any()));

    final awaiting = state() as AwaitingConfirmation;
    expect(awaiting.sessionId, sessionId);
    expect(awaiting.card.idNumber, '000000000001');
    expect(awaiting.card.fullName, 'NGUYEN VAN AN');
    expect(awaiting.card.placeOfBirth, 'Tinh Lam Dong');
  });

  test('bấm Lưu thì mã hóa JWE, gửi submitCard và hiện kết quả VERIFIED', () async {
    cardReturns([sampleCardText()]);
    submitReturns(const Verified());

    await scanAndTap();
    await notifier().confirm();

    final sent =
        verify(() => api.submitCard(sessionId, captureAny())).captured.single as SubmitCardRequest;
    expect(sent.card.idNumber, '000000000001');
    expect(sent.encryptedFields, 'mock.jwe.token');
    expect((state() as Completed).outcome, isA<Verified>());
    // Ambient Shield duy trì qua ResultScreen lẫn khi Về trang chủ (reset)
    verifyNever(() => reader.stop());
    notifier().reset();
    verifyNever(() => reader.stop());
    verify(() => reader.cancel()).called(1);
  });

  test('Lưu bị lỗi mạng thì giữ thông tin để bấm lại', () async {
    cardReturns([sampleCardText()]);
    when(() => api.submitCard(sessionId, any())).thenThrow(const NetworkFailure());

    await scanAndTap();
    await notifier().confirm();

    final awaiting = state() as AwaitingConfirmation;
    expect(awaiting.failure, isA<NetworkFailure>());
    expect(awaiting.saving, isFalse);
    expect(awaiting.card.idNumber, '000000000001');
  });

  test('bấm Hủy thì bỏ thông tin tại máy và KHÔNG gọi API', () async {
    cardReturns([sampleCardText()]);

    await scanAndTap();
    await notifier().discard();

    expect(state(), isA<AwaitingQr>());
    verifyNever(() => api.submitCard(any(), any()));
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

  test('máy chủ từ chối khi bấm Lưu thì hiện reasonCode', () async {
    cardReturns([sampleCardText()]);
    submitReturns(const Rejected(reason: ReasonCode.sessionNotOwned));

    await scanAndTap();
    await notifier().confirm();

    expect(((state() as Completed).outcome as Rejected).reason, ReasonCode.sessionNotOwned);
  });

  test('đăng xuất thì bỏ luồng đang dở, kể cả thông tin thẻ', () async {
    cardReturns([sampleCardText()]);

    await scanAndTap();
    container.read(sessionProvider.notifier).signOut();

    expect(state(), isA<AwaitingQr>());
  });
}
