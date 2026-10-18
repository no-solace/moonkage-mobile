import 'package:moonkage_verify/core/errors/app_failure.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';

/// Trạng thái luồng xác minh. Thông tin thẻ chỉ nằm trong bộ nhớ, bị bỏ khi xong, hủy hoặc đăng xuất.
sealed class VerifyFlowState {
  const VerifyFlowState();
}

final class AwaitingQr extends VerifyFlowState {
  const AwaitingQr();
}

/// Đã có phiên, chờ chạm thẻ. [issue] hoặc [failure] là lỗi của lần chạm trước.
final class AwaitingCard extends VerifyFlowState {
  const AwaitingCard({required this.sessionId, this.issue, this.failure});

  final String sessionId;
  final CardIssue? issue;
  final AppFailure? failure;
}

final class ReadingCard extends VerifyFlowState {
  const ReadingCard({required this.sessionId});

  final String sessionId;
}

/// Thông tin thẻ đã giải mã trong RAM; hiển thị chỉ đọc tại máy để người dùng kiểm tra
/// trước khi bấm Lưu (mã hóa JWE gửi máy chủ) hoặc Hủy (xóa RAM) theo Software Design D-20.
final class AwaitingConfirmation extends VerifyFlowState {
  const AwaitingConfirmation({
    required this.sessionId,
    required this.card,
    this.saving = false,
    this.failure,
  });

  final String sessionId;
  final IdentityCard card;
  final bool saving;

  /// Lỗi mạng của lần bấm Lưu trước; vẫn giữ thông tin để bấm lại.
  final AppFailure? failure;
}

final class Completed extends VerifyFlowState {
  const Completed({required this.outcome});

  final VerifyOutcome outcome;
}

enum CardIssue {
  /// Không có Text record là JSON có `id_number` (thẻ trắng, thẻ URL…). Không gửi lên máy chủ.
  wrongCard,

  /// Là thẻ Moonkage nhưng thiếu hoặc sai trường. Không gửi lên máy chủ.
  badFormat,
  readFailed,
}
