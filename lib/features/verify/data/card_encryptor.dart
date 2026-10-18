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
  JweCardEncryptor({String? publicKey, String? keyId})
    : _publicKey = publicKey ?? AppConfig.nfcTransportPublicKey,
      _keyId = keyId ?? AppConfig.nfcTransportKeyId;

  final String _publicKey;
  final String _keyId;
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
    // Dùng khóa demo khi chưa truyền biến môi trường (dev / test)
    return _cachedKey = JsonWebKey.fromJson(demoPublicKeyJwk);
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
