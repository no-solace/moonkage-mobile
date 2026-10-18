import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:moonkage_verify/core/auth/auth_session.dart';

abstract interface class TokenStorage {
  Future<void> saveSession({required String token, required String fullName});
  Future<AuthSession?> readSession();
  Future<void> clearSession();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _fullNameKey = 'auth_full_name';

  @override
  Future<void> saveSession({required String token, required String fullName}) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _fullNameKey, value: fullName);
    } on Object catch (_) {}
  }

  @override
  Future<AuthSession?> readSession() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.trim().isEmpty) return null;
      final fullName = await _storage.read(key: _fullNameKey) ?? '';
      return AuthSession(token: token, fullName: fullName);
    } on Object catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _fullNameKey);
    } on Object catch (_) {}
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return const SecureTokenStorage(
    FlutterSecureStorage(
      aOptions: AndroidOptions.defaultOptions,
    ),
  );
});
