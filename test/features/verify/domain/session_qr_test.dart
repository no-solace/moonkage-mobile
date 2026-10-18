import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/features/verify/domain/session_qr.dart';

void main() {
  const uuid = '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c';

  test('QR đúng dạng tiền tố v1, v2 hoặc không version thì lấy được session_id', () {
    expect(SessionQr.tryParse('moonkage-verify:v1:$uuid')?.sessionId, uuid);
    expect(SessionQr.tryParse('moonkage-verify:v2:$uuid')?.sessionId, uuid);
    expect(SessionQr.tryParse('moonkage-verify:$uuid')?.sessionId, uuid);
  });

  test('bỏ khoảng trắng đầu cuối', () {
    expect(SessionQr.tryParse('  moonkage-verify:v1:$uuid\n')?.sessionId, uuid);
  });

  test('hỗ trợ định dạng Web URL chứa query session hoặc path nfc-sessions', () {
    expect(
      SessionQr.tryParse('https://verify.moonkage.edu.vn/verify?session=$uuid')?.sessionId,
      uuid,
    );
    expect(
      SessionQr.tryParse('https://verify.moonkage.edu.vn/nfc-sessions/$uuid')?.sessionId,
      uuid,
    );
  });

  test('QR sai tiền tố hoặc URL lạ không đúng cấu trúc thì trả về null', () {
    expect(SessionQr.tryParse('wrong-prefix:$uuid'), isNull);
    expect(SessionQr.tryParse('https://evil.example/other/path'), isNull);
    expect(SessionQr.tryParse('not-a-qr-code'), isNull);
  });

  test('session_id rỗng, quá ngắn hoặc có ký tự lạ thì trả về null', () {
    expect(SessionQr.tryParse('moonkage-verify:v1:'), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v1:abc123'), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v1:../../admin/0123456789'), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v1:${'a' * 129}'), isNull);
  });
}
