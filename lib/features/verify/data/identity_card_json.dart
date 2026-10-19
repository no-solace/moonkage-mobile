import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Chuyển [IdentityCard] sang JSON của API và ngược lại. Ngày dạng `yyyy-MM-dd`,
/// giới tính `MALE`/`FEMALE`.
abstract final class IdentityCardJson {
  static Map<String, Object?> toJson(IdentityCard card) => {
    'idNumber': card.idNumber,
    'fullName': card.fullName,
    'dateOfBirth': formatDate(card.dateOfBirth),
    'gender': switch (card.gender) {
      Gender.male => 'MALE',
      Gender.female => 'FEMALE',
    },
    'nationality': card.nationality,
    'placeOfBirth': card.placeOfBirth,
    'placeOfResidence': card.placeOfResidence,
    'dateOfIssue': formatDate(card.dateOfIssue),
    'dateOfExpiry': formatDate(card.dateOfExpiry),
  };

  /// Ném [TypeError] hoặc [FormatException] khi JSON sai dạng.
  static IdentityCard fromJson(Map<String, Object?> json) => IdentityCard(
    idNumber: json['idNumber']! as String,
    fullName: json['fullName']! as String,
    dateOfBirth: _parseDate(json['dateOfBirth']! as String),
    gender: switch (json['gender']! as String) {
      'MALE' => Gender.male,
      'FEMALE' => Gender.female,
      final other => throw FormatException('gender không hợp lệ', other),
    },
    nationality: json['nationality']! as String,
    placeOfBirth: json['placeOfBirth']! as String,
    placeOfResidence: json['placeOfResidence']! as String,
    dateOfIssue: _parseDate(json['dateOfIssue']! as String),
    dateOfExpiry: _parseDate(json['dateOfExpiry']! as String),
  );

  static String formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String value) {
    final parsed = DateTime.parse(value);
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }
}
