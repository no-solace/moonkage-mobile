import 'package:flutter_test/flutter_test.dart';
import 'package:jose/jose.dart';
import 'package:moonkage_verify/features/verify/data/card_encryptor.dart';
import 'package:moonkage_verify/features/verify/data/demo_nfc_key.dart';

void main() {
  test('JweCardEncryptor mã hóa JWE compact (RSA-OAEP-256 + A256GCM) và giải mã được', () async {
    final encryptor = JweCardEncryptor();

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
}
