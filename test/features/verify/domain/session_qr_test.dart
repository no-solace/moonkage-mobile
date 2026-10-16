import 'package:flutter_test/flutter_test.dart';
import 'package:moonkage_verify/features/verify/domain/session_qr.dart';

void main() {
  const uuid = '3f2b8c1e-9a4d-4e7b-8c2a-1d5e6f7a8b9c';

  test('QR đúng dạng thì lấy được session_id', () {
    expect(SessionQr.tryParse('moonkage-verify:v1:$uuid')?.sessionId, uuid);
  });

  test('bỏ khoảng trắng đầu cuối', () {
    expect(SessionQr.tryParse('  moonkage-verify:v1:$uuid\n')?.sessionId, uuid);
  });

  test('QR sai tiền tố hoặc sai phiên bản thì trả về null', () {
    expect(SessionQr.tryParse(uuid), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v2:$uuid'), isNull);
    expect(SessionQr.tryParse('https://evil.example/moonkage-verify:v1:$uuid'), isNull);
  });

  test('session_id rỗng, quá ngắn hoặc có ký tự lạ thì trả về null', () {
    expect(SessionQr.tryParse('moonkage-verify:v1:'), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v1:abc123'), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v1:../../admin/0123456789'), isNull);
    expect(SessionQr.tryParse('moonkage-verify:v1:${'a' * 129}'), isNull);
  });
}
