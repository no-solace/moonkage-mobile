import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/config/app_version_provider.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/features/verify/data/card_encryptor.dart';
import 'package:moonkage_verify/features/verify/data/identity_card_json.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/data/verify_api.dart';
import 'package:moonkage_verify/features/verify/domain/card_parser.dart';
import 'package:moonkage_verify/features/verify/domain/session_qr.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

final verifyFlowProvider = NotifierProvider<VerifyFlowNotifier, VerifyFlowState>(
  VerifyFlowNotifier.new,
);

/// Giữ luồng QR → chạm thẻ → xác nhận tại máy → mã hóa và gửi kết quả (Software Design D-20).
class VerifyFlowNotifier extends Notifier<VerifyFlowState> {
  @override
  VerifyFlowState build() {
    // Đổi tài khoản hoặc đăng xuất thì bỏ luồng đang dở, hủy phiên đọc dở nếu có.
    ref.watch(sessionProvider);
    final reader = ref.read(nfcReaderProvider);
    ref.onDispose(() {
      unawaited(reader.cancel());
    });
    return const AwaitingQr();
  }

  /// Trả về false nếu QR sai dạng; state giữ nguyên.
  bool acceptQr(String raw) {
    final qr = SessionQr.tryParse(raw);
    if (qr == null) return false;
    state = AwaitingCard(sessionId: qr.sessionId);
    return true;
  }

  Future<void> readCard() async {
    final current = state;
    if (current is! AwaitingCard) return;
    final sessionId = current.sessionId;
    state = ReadingCard(sessionId: sessionId);

    final List<String> textRecords;
    try {
      textRecords = await ref.read(nfcReaderProvider).readTextRecords();
    } on NfcReadCancelled {
      if (ref.mounted) state = AwaitingCard(sessionId: sessionId);
      return;
    } on NfcReadException {
      if (ref.mounted) state = AwaitingCard(sessionId: sessionId, issue: CardIssue.readFailed);
      return;
    }
    if (!ref.mounted) return;

    final cardText = pickCardText(textRecords);
    final card = cardText == null ? null : parseCardText(cardText);
    if (card == null) {
      final issue = cardText == null ? CardIssue.wrongCard : CardIssue.badFormat;
      state = AwaitingCard(sessionId: sessionId, issue: issue);
      return;
    }

    // Hiển thị ngay thông tin tại máy để người dùng xác nhận trước khi gửi (AC-04.4, D-20).
    state = AwaitingConfirmation(sessionId: sessionId, card: card);
  }

  Future<void> cancelRead() => ref.read(nfcReaderProvider).cancel();

  /// Người dùng bấm Lưu: mã hóa JWE các trường nhạy cảm và gửi lên máy chủ.
  Future<void> confirm() async {
    final current = state;
    if (current is! AwaitingConfirmation || current.saving) return;
    state = AwaitingConfirmation(sessionId: current.sessionId, card: current.card, saving: true);
    try {
      final appVersion = await ref.read(appVersionProvider.future);
      final encryptedFields = await ref
          .read(cardEncryptorProvider)
          .encryptFields(
            idNumber: current.card.idNumber,
            dateOfBirth: IdentityCardJson.formatDate(current.card.dateOfBirth),
            placeOfResidence: current.card.placeOfResidence,
          );
      final request = SubmitCardRequest(
        card: current.card,
        encryptedFields: encryptedFields,
        appVersion: appVersion,
      );
      final outcome = await ref.read(verifyApiProvider).submitCard(current.sessionId, request);
      if (ref.mounted) {
        state = Completed(outcome: outcome);
      }
    } on UnauthorizedFailure {
      // Interceptor đã đăng xuất; router đưa về màn đăng nhập.
      if (ref.mounted) {
        unawaited(ref.read(nfcReaderProvider).cancel());
        state = const AwaitingQr();
      }
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = AwaitingConfirmation(
        sessionId: current.sessionId,
        card: current.card,
        failure: failure,
      );
    }
  }

  /// Người dùng bấm Hủy: bỏ thông tin ở app ngay, máy chủ chưa lưu tạm nên không cần gọi API.
  Future<void> discard() async {
    await ref.read(nfcReaderProvider).cancel();
    state = const AwaitingQr();
  }

  /// Về trang chủ và bỏ kết quả khỏi bộ nhớ (duy trì Ambient Shield).
  void reset() {
    unawaited(ref.read(nfcReaderProvider).cancel());
    state = const AwaitingQr();
  }
}
