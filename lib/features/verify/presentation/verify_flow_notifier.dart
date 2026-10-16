import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonkage_verify/core/auth/session_notifier.dart';
import 'package:moonkage_verify/core/config/app_version_provider.dart';
import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/features/verify/data/submit_card_request.dart';
import 'package:moonkage_verify/features/verify/data/verify_api.dart';
import 'package:moonkage_verify/features/verify/domain/card_parser.dart';
import 'package:moonkage_verify/features/verify/domain/session_qr.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';
import 'package:moonkage_verify/features/verify/presentation/verify_flow_state.dart';
import 'package:moonkage_verify/nfc/nfc_reader.dart';

final verifyFlowProvider = NotifierProvider<VerifyFlowNotifier, VerifyFlowState>(
  VerifyFlowNotifier.new,
);

/// Giữ luồng QR → chạm thẻ → gửi (lưu tạm) → xác nhận → kết quả.
class VerifyFlowNotifier extends Notifier<VerifyFlowState> {
  @override
  VerifyFlowState build() {
    // Đổi tài khoản hoặc đăng xuất thì bỏ luồng đang dở, kể cả thông tin thẻ.
    ref.watch(sessionProvider);
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

    state = Submitting(sessionId: sessionId);
    try {
      final appVersion = await ref.read(appVersionProvider.future);
      final outcome = await ref
          .read(verifyApiProvider)
          .submitCard(sessionId, SubmitCardRequest(card: card, appVersion: appVersion));
      if (!ref.mounted) return;
      state = switch (outcome) {
        PendingConfirmation(:final card) => AwaitingConfirmation(sessionId: sessionId, card: card),
        Verified() || Rejected() => Completed(outcome: outcome),
      };
    } on UnauthorizedFailure {
      // Interceptor đã đăng xuất; router đưa về màn đăng nhập.
      if (ref.mounted) state = const AwaitingQr();
    } on AppFailure catch (failure) {
      if (ref.mounted) state = AwaitingCard(sessionId: sessionId, failure: failure);
    }
  }

  Future<void> cancelRead() => ref.read(nfcReaderProvider).cancel();

  /// Người dùng bấm Lưu.
  Future<void> confirm() async {
    final current = state;
    if (current is! AwaitingConfirmation || current.saving) return;
    state = AwaitingConfirmation(sessionId: current.sessionId, card: current.card, saving: true);
    try {
      final outcome = await ref.read(verifyApiProvider).confirm(current.sessionId);
      if (ref.mounted) state = Completed(outcome: outcome);
    } on UnauthorizedFailure {
      if (ref.mounted) state = const AwaitingQr();
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = AwaitingConfirmation(
        sessionId: current.sessionId,
        card: current.card,
        failure: failure,
      );
    }
  }

  /// Người dùng bấm Hủy: bỏ thông tin ở app ngay, nhờ máy chủ xóa bản lưu tạm.
  Future<void> discard() async {
    final current = state;
    state = const AwaitingQr();
    if (current is! AwaitingConfirmation) return;
    try {
      await ref.read(verifyApiProvider).discard(current.sessionId);
    } on AppFailure {
      // Không chặn người dùng: bản lưu tạm tự hết hạn cùng phiên (5 phút).
    }
  }

  /// Về trang chủ và bỏ kết quả khỏi bộ nhớ.
  void reset() => state = const AwaitingQr();
}
