import 'package:moonkage_verify/core/network/api_endpoints.dart';
import 'package:moonkage_verify/features/verify/data/identity_card_json.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Body của [ApiEndpoints.nfcSessionCard] (Software Design D-17, D-20).
/// Ba trường nhạy cảm idNumber, dateOfBirth, placeOfResidence được bọc trong [encryptedFields].
final class SubmitCardRequest {
  const SubmitCardRequest({
    required this.card,
    required this.encryptedFields,
    required this.appVersion,
  });

  final IdentityCard card;
  final String encryptedFields;
  final String appVersion;

  Map<String, Object?> toJson() => {
    'fullName': card.fullName,
    'gender': switch (card.gender) {
      Gender.male => 'MALE',
      Gender.female => 'FEMALE',
    },
    'nationality': card.nationality,
    'placeOfBirth': card.placeOfBirth,
    'dateOfIssue': IdentityCardJson.formatDate(card.dateOfIssue),
    'dateOfExpiry': IdentityCardJson.formatDate(card.dateOfExpiry),
    'encryptedFields': encryptedFields,
    'appVersion': appVersion,
  };
}
