import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jose/jose.dart';
import 'package:moonkage_verify/core/config/app_config.dart';
import 'package:moonkage_verify/features/verify/data/demo_nfc_key.dart';

abstract interface class CardEncryptor {
  Future<String> encryptFields({
    required String idNumber,
    required String dateOfBirth,
    required String placeOfResidence,
  });
}

final cardEncryptorProvider = Provider<CardEncryptor>((ref) => JweCardEncryptor());

/// Mã hóa JWE compact (RSA-OAEP-256 + A256GCM) bọc {idNumber, dateOfBirth, placeOfResidence}
/// theo Software Design D-17 và AC-04.10.
final class JweCardEncryptor implements CardEncryptor {
  JweCardEncryptor({String? publicKey, String? keyId, bool? useDemoKey})
    : _publicKey = publicKey ?? AppConfig.nfcTransportPublicKey,
      _keyId = keyId ?? AppConfig.nfcTransportKeyId,
      _useDemoKey = useDemoKey ?? AppConfig.useDemoNfcKey;

  final String _publicKey;
  final String _keyId;
  final bool _useDemoKey;
  JsonWebKey? _cachedKey;

  JsonWebKey _getKey() {
    final cached = _cachedKey;
    if (cached != null) return cached;

    final trimmed = _publicKey.trim();
    if (trimmed.isNotEmpty) {
      if (trimmed.contains('-----BEGIN')) {
        return _cachedKey = JsonWebKey.fromPem(
          trimmed,
          keyId: _keyId.isNotEmpty ? _keyId : null,
        );
      }
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      if (_keyId.isNotEmpty && !json.containsKey('kid')) {
        json['kid'] = _keyId;
      }
      if (json['use'] == 'enc' && !json.containsKey('key_ops')) {
        json.remove('use');
      }
      return _cachedKey = JsonWebKey.fromJson(json);
    }
    // Khóa demo chỉ khớp mock server; với identity-service thật phải truyền NFC_TRANSPORT_PUBLIC_KEY
    if (_useDemoKey) return _cachedKey = JsonWebKey.fromJson(demoPublicKeyJwk);
    throw StateError('NFC_TRANSPORT_PUBLIC_KEY chưa được cấu hình');
  }

  @override
  Future<String> encryptFields({
    required String idNumber,
    required String dateOfBirth,
    required String placeOfResidence,
  }) async {
    final key = _getKey();
    final builder = JsonWebEncryptionBuilder()
      ..jsonContent = {
        'idNumber': idNumber,
        'dateOfBirth': dateOfBirth,
        'placeOfResidence': placeOfResidence,
      }
      ..encryptionAlgorithm = 'A256GCM'
      ..addRecipient(key, algorithm: 'RSA-OAEP-256');

    final jwe = builder.build();
    return jwe.toCompactSerialization();
  }
}
