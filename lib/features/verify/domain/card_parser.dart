import 'dart:convert';

import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Khóa nhận diện thẻ Moonkage: Text record là JSON object có khóa này.
const cardMarkerKey = 'id_number';

/// Chọn Text record đầu tiên là JSON object có `id_number`; không có thì thẻ không đúng loại.
String? pickCardText(Iterable<String> textRecords) => textRecords
    .where((text) => _decodeObject(text)?.containsKey(cardMarkerKey) ?? false)
    .firstOrNull;

final _idNumber = RegExp(r'^\d{12}$');
final _unaccentedName = RegExp(r'^[A-Z]+( [A-Z]+)*$');
final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Đọc nội dung thẻ, một JSON object (docs/NFC_CARD_GUIDE.md mục 2):
///
/// ```json
/// {"id_number":"000000000001","full_name":"NGUYEN VAN AN","date_of_birth":"1990-01-01",
///  "gender":"Nam","nationality":"Viet Nam","place_of_birth":"Tinh Lam Dong",
///  "place_of_residence":"So 1 Duong ...","date_of_issue":"2024-01-01","date_of_expiry":"2030-01-01"}
/// ```
///
/// Thiếu trường hoặc sai bất kỳ trường nào thì trả về null; khóa lạ được bỏ qua.
/// Máy chủ vẫn kiểm lại; kiểm ở app chỉ để báo lỗi sớm.
IdentityCard? parseCardText(String text) {
  final json = _decodeObject(text);
  if (json == null) return null;

  String? field(String key) => switch (json[key]) {
    final String value when value.trim().isNotEmpty => value.trim(),
    _ => null,
  };

  final idNumber = field('id_number');
  final fullName = field('full_name');
  final dateOfBirth = _parseDate(field('date_of_birth'));
  final gender = _parseGender(field('gender'));
  final nationality = field('nationality');
  final placeOfBirth = field('place_of_birth');
  final placeOfResidence = field('place_of_residence');
  final dateOfIssue = _parseDate(field('date_of_issue'));
  final dateOfExpiry = _parseDate(field('date_of_expiry'));

  if (idNumber == null || !_idNumber.hasMatch(idNumber)) return null;
  if (fullName == null || !_unaccentedName.hasMatch(fullName)) return null;
  if (dateOfBirth == null || dateOfIssue == null || dateOfExpiry == null) return null;
  if (dateOfBirth.isAfter(dateOfIssue) || !dateOfIssue.isBefore(dateOfExpiry)) return null;
  if (gender == null || nationality == null || placeOfBirth == null || placeOfResidence == null) {
    return null;
  }

  return IdentityCard(
    idNumber: idNumber,
    fullName: fullName,
    dateOfBirth: dateOfBirth,
    gender: gender,
    nationality: nationality,
    placeOfBirth: placeOfBirth,
    placeOfResidence: placeOfResidence,
    dateOfIssue: dateOfIssue,
    dateOfExpiry: dateOfExpiry,
  );
}

Map<String, Object?>? _decodeObject(String text) {
  try {
    final json = jsonDecode(text);
    return json is Map<String, Object?> ? json : null;
  } on FormatException {
    return null;
  }
}

/// `yyyy-MM-dd` → ngày UTC; ngày không tồn tại (2000-02-31) thì trả về null.
DateTime? _parseDate(String? value) {
  final match = value == null ? null : _isoDate.firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  return date.year == year && date.month == month && date.day == day ? date : null;
}

/// Thẻ viết không dấu nên chấp nhận cả `Nu` lẫn `Nữ`.
Gender? _parseGender(String? value) => switch (value) {
  'Nam' => Gender.male,
  'Nữ' || 'Nu' => Gender.female,
  _ => null,
};
