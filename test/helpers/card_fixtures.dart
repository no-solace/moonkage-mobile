import 'dart:convert';

import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

/// Nội dung thẻ mẫu (A-08), không phải người thật. [overrides] thay hoặc thêm khóa;
/// giá trị `null` thì bỏ khóa đó.
String sampleCardText([Map<String, Object?> overrides = const {}]) {
  final json = <String, Object?>{
    'id_number': '000000000001',
    'full_name': 'NGUYEN VAN AN',
    'date_of_birth': '1990-01-01',
    'sex': 'Nam',
    'nationality': 'Viet Nam',
    'place_of_birth': 'Tinh Lam Dong',
    'place_of_residence': 'So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong',
    'date_of_issue': '2024-01-01',
    'date_of_expiry': '2030-01-01',
    ...overrides,
  }..removeWhere((_, value) => value == null);
  return jsonEncode(json);
}

final sampleCard = IdentityCard(
  idNumber: '000000000001',
  fullName: 'NGUYEN VAN AN',
  dateOfBirth: DateTime.utc(1990),
  sex: Sex.male,
  nationality: 'Viet Nam',
  placeOfBirth: 'Tinh Lam Dong',
  placeOfResidence: 'So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong',
  dateOfIssue: DateTime.utc(2024),
  dateOfExpiry: DateTime.utc(2030),
);
