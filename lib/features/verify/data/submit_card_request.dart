import 'package:moonkage_verify/features/verify/data/identity_card_json.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Body của `POST /identity-service/api/nfc-sessions/{sessionId}/card`. Không log, không lưu.
final class SubmitCardRequest {
  const SubmitCardRequest({required this.card, required this.appVersion});

  final IdentityCard card;
  final String appVersion;

  Map<String, Object?> toJson() => {...IdentityCardJson.toJson(card), 'appVersion': appVersion};
}
