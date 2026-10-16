import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/features/verify/domain/card_parser.dart';
import 'package:moonkage_verify/features/verify/domain/identity_card.dart';

import '../../../helpers/card_fixtures.dart';

void main() {
  group('pickCardText', () {
    test('chọn Text record đầu tiên là JSON có id_number', () {
      final card = sampleCardText();
      expect(
        pickCardText([
          'hello',
          '{"other":1}',
          card,
          sampleCardText({'id_number': '2'}),
        ]),
        card,
      );
    });

    test('thẻ trắng, thẻ URL, JSON không phải object, thẻ định dạng cũ thì trả về null', () {
      expect(pickCardText([]), isNull);
      expect(pickCardText(['https://moonkage.vn', '["id_number"]', 'MK1|001090000001|An']), isNull);
    });

    test('có id_number nhưng sai trường vẫn được chọn (để báo sai định dạng)', () {
      final card = sampleCardText({'id_number': '123'});
      expect(pickCardText([card]), card);
    });
  });

  group('parseCardText', () {
    test('đọc đủ các trường của thẻ hợp lệ', () {
      final card = parseCardText(sampleCardText())!;
      expect(card.idNumber, '000000000001');
      expect(card.fullName, 'NGUYEN VAN AN');
      expect(card.dateOfBirth, DateTime.utc(1990));
      expect(card.sex, Sex.male);
      expect(card.nationality, 'Viet Nam');
      expect(card.placeOfBirth, 'Tinh Lam Dong');
      expect(card.placeOfResidence, 'So 1 Duong Thu Nghiem, Phuong Sai Gon, TP Lam Dong');
      expect(card.dateOfIssue, DateTime.utc(2024));
      expect(card.dateOfExpiry, DateTime.utc(2030));
    });

    test('giới tính nữ viết Nu hoặc Nữ đều được', () {
      expect(parseCardText(sampleCardText({'sex': 'Nu'}))!.sex, Sex.female);
      expect(parseCardText(sampleCardText({'sex': 'Nữ'}))!.sex, Sex.female);
    });

    test('khóa lạ bị bỏ qua; khoảng trắng đầu cuối được cắt', () {
      final card = parseCardText(sampleCardText({'extra': 'x', 'nationality': ' Viet Nam '}))!;
      expect(card.nationality, 'Viet Nam');
    });

    test('không phải JSON object thì trả về null', () {
      expect(parseCardText('MK2|000000000001|NGUYEN VAN AN'), isNull);
      expect(parseCardText('[]'), isNull);
      expect(parseCardText('{"id_number": '), isNull);
    });

    test('thiếu trường, trường rỗng hoặc sai kiểu thì trả về null', () {
      expect(parseCardText(sampleCardText({'place_of_residence': null})), isNull);
      expect(parseCardText(sampleCardText({'place_of_birth': '  '})), isNull);
      expect(parseCardText(sampleCardText({'id_number': 1})), isNull);
    });

    test('CCCD không đủ 12 chữ số thì trả về null', () {
      expect(parseCardText(sampleCardText({'id_number': '00000000001'})), isNull);
      expect(parseCardText(sampleCardText({'id_number': '00000000000A'})), isNull);
    });

    test('tên có dấu, chữ thường hoặc thừa khoảng trắng giữa thì trả về null', () {
      expect(parseCardText(sampleCardText({'full_name': 'NGUYỄN VĂN AN'})), isNull);
      expect(parseCardText(sampleCardText({'full_name': 'Nguyen Van An'})), isNull);
      expect(parseCardText(sampleCardText({'full_name': 'NGUYEN  VAN AN'})), isNull);
    });

    test('ngày sai dạng, không tồn tại hoặc sai thứ tự thì trả về null', () {
      expect(parseCardText(sampleCardText({'date_of_birth': '01011990'})), isNull);
      expect(parseCardText(sampleCardText({'date_of_birth': '2000-02-31'})), isNull);
      expect(parseCardText(sampleCardText({'date_of_issue': '1989-01-01'})), isNull);
      expect(parseCardText(sampleCardText({'date_of_expiry': '2024-01-01'})), isNull);
    });

    test('giới tính lạ thì trả về null', () {
      expect(parseCardText(sampleCardText({'sex': 'M'})), isNull);
    });
  });
}
