import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Kết quả máy chủ trả về sau khi gửi thẻ hoặc xác nhận.
sealed class VerifyOutcome {
  const VerifyOutcome();
}

/// [Legacy] Máy chủ đã lưu tạm [card] (thiết kế 2-step cũ). Giữ lại để tương thích ngược.
final class PendingConfirmation extends VerifyOutcome {
  const PendingConfirmation({required this.card, this.expiresAt});

  final IdentityCard card;
  final DateTime? expiresAt;
}

/// Đã ghi thông tin thẻ vào tài khoản.
final class Verified extends VerifyOutcome {
  const Verified();
}

final class Rejected extends VerifyOutcome {
  const Rejected({required this.reason, this.attemptsLeft, this.lockedUntil});

  final ReasonCode reason;
  final int? attemptsLeft;
  final DateTime? lockedUntil;
}
