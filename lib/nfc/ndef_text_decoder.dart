import 'dart:convert';

import 'package:nfc_manager/ndef_record.dart';

const _textRecordType = 0x54; // 'T'

/// Giải mã NDEF Text record (NFC Forum RTD-Text). Không phải Text record thì trả về null.
///
/// Byte đầu payload: bit 7 = UTF-16, bit 0–5 = độ dài mã ngôn ngữ; phần còn lại là văn bản.
String? decodeTextRecord(NdefRecord record) {
  if (record.typeNameFormat != TypeNameFormat.wellKnown) return null;
  if (record.type.length != 1 || record.type.first != _textRecordType) return null;

  final payload = record.payload;
  if (payload.isEmpty) return null;
  final status = payload.first;
  final textStart = 1 + (status & 0x3F);
  if (textStart > payload.length) return null;
  final body = payload.sublist(textStart);

  if (status & 0x80 != 0) return _decodeUtf16(body);
  try {
    return utf8.decode(body);
  } on FormatException {
    return null;
  }
}

String? _decodeUtf16(List<int> bytes) {
  if (bytes.length.isOdd) return null;
  var bigEndian = true;
  var offset = 0;
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    bigEndian = false;
    offset = 2;
  } else if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    offset = 2;
  }
  return String.fromCharCodes([
    for (var i = offset; i < bytes.length; i += 2)
      bigEndian ? (bytes[i] << 8) | bytes[i + 1] : (bytes[i + 1] << 8) | bytes[i],
  ]);
}
