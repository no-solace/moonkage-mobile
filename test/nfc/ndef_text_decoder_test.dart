import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/nfc/ndef_text_decoder.dart';
import 'package:nfc_manager/ndef_record.dart';

NdefRecord _record({
  TypeNameFormat tnf = TypeNameFormat.wellKnown,
  List<int> type = const [0x54],
  required List<int> payload,
}) => NdefRecord(
  typeNameFormat: tnf,
  type: Uint8List.fromList(type),
  identifier: Uint8List(0),
  payload: Uint8List.fromList(payload),
);

void main() {
  const card = 'MK1|001090000001|Nguyễn Văn An';

  test('đọc Text record UTF-8 như NFC Tools ghi (mã ngôn ngữ "en")', () {
    final payload = [0x02, ...ascii.encode('en'), ...utf8.encode(card)];
    expect(decodeTextRecord(_record(payload: payload)), card);
  });

  test('đọc Text record UTF-16 có BOM', () {
    final units = card.codeUnits;
    final payload = [
      0x80 | 0x02,
      ...ascii.encode('vi'),
      0xFE,
      0xFF,
      for (final u in units) ...[u >> 8, u & 0xFF],
    ];
    expect(decodeTextRecord(_record(payload: payload)), card);
  });

  test('record URI hoặc MIME thì trả về null', () {
    expect(
      decodeTextRecord(_record(type: [0x55], payload: [0x04, ...ascii.encode('a.vn')])),
      isNull,
    );
    expect(
      decodeTextRecord(
        _record(tnf: TypeNameFormat.media, type: ascii.encode('text/plain'), payload: [0x41]),
      ),
      isNull,
    );
  });

  test('payload hỏng thì trả về null', () {
    expect(decodeTextRecord(_record(payload: [0x05, 0x65])), isNull);
    expect(decodeTextRecord(_record(payload: [0x00, 0xC3, 0x28])), isNull);
  });
}
