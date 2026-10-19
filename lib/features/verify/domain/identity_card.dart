enum Gender { male, female }

/// Thông tin trên thẻ Moonkage (docs/NFC_CARD_GUIDE.md mục 2). Ngày chỉ có phần ngày, lưu ở UTC.
final class IdentityCard {
  const IdentityCard({
    required this.idNumber,
    required this.fullName,
    required this.dateOfBirth,
    required this.gender,
    required this.nationality,
    required this.placeOfBirth,
    required this.placeOfResidence,
    required this.dateOfIssue,
    required this.dateOfExpiry,
  });

  /// 12 chữ số.
  final String idNumber;

  /// Họ tên không dấu, chữ in hoa: `NGUYEN VAN AN`.
  final String fullName;
  final DateTime dateOfBirth;
  final Gender gender;
  final String nationality;
  final String placeOfBirth;

  /// Nơi thường trú.
  final String placeOfResidence;
  final DateTime dateOfIssue;
  final DateTime dateOfExpiry;
}
