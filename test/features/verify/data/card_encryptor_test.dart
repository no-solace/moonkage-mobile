import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:moonkage_verify/features/verify/data/card_encryptor.dart';
import 'package:moonkage_verify/features/verify/data/demo_nfc_key.dart';

void main() {
  test('JweCardEncryptor mã hóa JWE compact (RSA-OAEP-256 + A256GCM) và giải mã được', () async {
    final encryptor = JweCardEncryptor(publicKey: '', useDemoKey: true);

    final compact = await encryptor.encryptFields(
      idNumber: '000000000001',
      dateOfBirth: '1990-01-01',
      placeOfResidence: 'Tinh Lam Dong',
    );

    expect(compact, isNotEmpty);
    expect(compact.split('.').length, 5); // JWE compact format: 5 parts

    // Giải mã bằng khóa riêng demo
    final jwe = JsonWebEncryption.fromCompactSerialization(compact);
    final keyStore = JsonWebKeyStore()..addKey(JsonWebKey.fromJson(demoPrivateKeyJwk));
    final payload = await jwe.getPayload(keyStore);
    final map = payload.jsonContent as Map<String, dynamic>;

    expect(map['idNumber'], '000000000001');
    expect(map['dateOfBirth'], '1990-01-01');
    expect(map['placeOfResidence'], 'Tinh Lam Dong');
  });

  test('nhận PEM viết trên một dòng (dart-define trên Windows không chứa được xuống dòng)', () async {
    const body =
        'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAl1TBisCcfIQyWWz7+reyzIasPm3x75Dycvz4KMTMTHW6SGV3WGK9oOqzZ/4MFOyVoHj9mmdb4vVJmD1TI3ydEX91wdbguCBumhJwFTAHvwnqAqA0tjxHA9xoMnZqbACfXRiKSGslJYgEwpL8FNVEYXS0JANsalD9fUeaovT50GLQuiBfJ/PicQXl2UrBZfYQaK6L8AUGt5b/lAaPfW5td+Nxdc/nC3hHuWK4+FQp9myPm+qHHNE0ZUyFd54M4uxP5m5Fiwyr20fMvjWd3jouaSSmitExBLGpRExI31H8AvcMV8IzYq7qKV2g95j2qrLV/LJpwUKqHVafiC+NGZBnCQIDAQAB';
    final encryptor = JweCardEncryptor(
      publicKey: '-----BEGIN PUBLIC KEY-----$body-----END PUBLIC KEY-----',
      keyId: 'nfc-transport-v1',
      useDemoKey: false,
    );

    final compact = await encryptor.encryptFields(
      idNumber: '000000000001',
      dateOfBirth: '1990-01-01',
      placeOfResidence: 'Tinh Lam Dong',
    );

    expect(compact.split('.').length, 5);
  });

  test('thiếu khóa công khai và không bật khóa demo thì báo lỗi, không mã hóa bằng khóa demo', () {
    final encryptor = JweCardEncryptor(publicKey: '', useDemoKey: false);

    expect(
      () => encryptor.encryptFields(
        idNumber: '000000000001',
        dateOfBirth: '1990-01-01',
        placeOfResidence: 'Tinh Lam Dong',
      ),
      throwsStateError,
    );
  });
}
