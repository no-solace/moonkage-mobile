// Kiểm nội dung thẻ (JSON) và xem có vừa thẻ NTAG không.
//
// Chạy:  dart run tool/make_card.dart tool/card_sample.json [--out card.txt]
//
// Đầu vào là chính JSON của thẻ (docs/NFC_CARD_GUIDE.md mục 2). Tool kiểm định dạng giống app,
// rút gọn thành một dòng (bỏ khoảng trắng thừa giữa các khóa) để tốn ít byte nhất, rồi báo số byte.
// Kết quả để dán vào NFC Tools (Write → Add a record → Text).
import 'dart:convert';
import 'dart:io';

import 'package:moonkage_verify/features/verify/domain/card_parser.dart';

/// Bộ nhớ người dùng của từng loại thẻ (byte).
const _tagCapacity = {'NTAG213': 144, 'NTAG215': 504, 'NTAG216': 888};

Future<void> main(List<String> args) async {
  final outIndex = args.indexOf('--out');
  final outPath = outIndex >= 0 && outIndex + 1 < args.length ? args[outIndex + 1] : null;
  final inputs = [
    for (var i = 0; i < args.length; i++)
      if (outIndex < 0 || (i != outIndex && i != outIndex + 1)) args[i],
  ];
  if (inputs.length != 1) {
    stderr.writeln('Cách dùng: dart run tool/make_card.dart <card.json> [--out card.txt]');
    exitCode = 64;
    return;
  }

  final Object? json;
  try {
    json = jsonDecode(await File(inputs.single).readAsString());
  } on FormatException catch (e) {
    stderr.writeln('File không phải JSON hợp lệ: ${e.message}');
    exitCode = 65;
    return;
  }

  final line = jsonEncode(json);
  if (parseCardText(line) == null) {
    stderr.writeln('Nội dung thẻ không hợp lệ (docs/NFC_CARD_GUIDE.md mục 2).');
    exitCode = 65;
    return;
  }

  final size = _ndefSize(line);
  stdout
    ..writeln('Văn bản: ${utf8.encode(line).length} byte')
    ..writeln('Cần trên thẻ: $size byte');
  for (final MapEntry(key: tag, value: capacity) in _tagCapacity.entries) {
    stdout.writeln('  $tag ($capacity byte): ${size <= capacity ? 'vừa' : 'KHÔNG vừa'}');
  }

  if (outPath != null) {
    await File(outPath).writeAsString(line);
    stdout.writeln('Đã ghi ra $outPath');
  } else {
    stdout
      ..writeln()
      ..writeln(line);
  }
}

/// Số byte NDEF TLV cần cho một Text record mã ngôn ngữ `en` chứa [text].
int _ndefSize(String text) {
  final payload = 1 + 2 + utf8.encode(text).length; // byte trạng thái + "en" + văn bản
  // header, độ dài type, độ dài payload, type "T"
  final record = 1 + 1 + (payload < 256 ? 1 : 4) + 1 + payload;
  return 1 + (record < 255 ? 1 : 3) + record + 1; // 0x03, độ dài, message, 0xFE
}
