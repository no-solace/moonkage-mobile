import 'package:moonkage_verify/core/errors/reason_code.dart';
import 'package:moonkage_verify/features/verify/data/identity_card_json.dart';
import 'package:moonkage_verify/features/verify/domain/verify_outcome.dart';

/// Phản hồi của bước gửi thẻ và bước xác nhận.
///
/// `status`: `PENDING_CONFIRMATION` (kèm `card`, `expiresAt`), `VERIFIED`, hoặc `REJECTED`
/// (kèm `reasonCode`, `attemptsLeft`, `lockedUntil`).
abstract final class SessionResultResponse {
  static const pendingStatus = 'PENDING_CONFIRMATION';
  static const verifiedStatus = 'VERIFIED';
  static const rejectedStatus = 'REJECTED';

  /// Ném [TypeError] hoặc [FormatException] khi JSON sai dạng.
  static VerifyOutcome fromJson(Map<String, Object?> json) {
    switch (json['status']! as String) {
      case pendingStatus:
        final expiresAt = json['expiresAt'] as String?;
        return PendingConfirmation(
          card: IdentityCardJson.fromJson(json['card']! as Map<String, Object?>),
          expiresAt: expiresAt == null ? null : DateTime.parse(expiresAt),
        );
      case verifiedStatus:
        return const Verified();
      case rejectedStatus:
        final lockedUntil = json['lockedUntil'] as String?;
        return Rejected(
          reason: ReasonCode.fromCode(json['reasonCode'] as String?),
          attemptsLeft: json['attemptsLeft'] as int?,
          lockedUntil: lockedUntil == null ? null : DateTime.parse(lockedUntil),
        );
      case final other:
        throw FormatException('status không hợp lệ', other);
    }
  }
}
