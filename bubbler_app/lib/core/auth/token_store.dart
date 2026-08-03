import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure persistence for the OAuth access token.
///
/// Mirrors Swift `KeychainStore`: service `com.bubbler.access-token`,
/// account `access_token`, and after-first-unlock accessibility on Apple
/// platforms.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accountName: _service,
                accessibility: KeychainAccessibility.first_unlock,
              ),
              mOptions: MacOsOptions(
                accountName: _service,
                accessibility: KeychainAccessibility.first_unlock,
              ),
              aOptions: AndroidOptions(),
            );

  static const _service = 'com.bubbler.access-token';
  static const _account = 'access_token';

  final FlutterSecureStorage _storage;

  /// Loads the stored access token, or `null` if none is present.
  Future<String?> loadAccessToken() {
    return _storage.read(key: _account);
  }

  /// Persists [token], replacing any previous value.
  Future<void> saveAccessToken(String token) async {
    try {
      await _storage.write(key: _account, value: token);
    } on PlatformException catch (error) {
      throw TokenStoreException.saveFailed(error);
    }
  }

  /// Removes the access token. No-op when nothing is stored.
  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _account);
  }
}

/// Secure-storage failures, mirroring Swift `KeychainError`.
class TokenStoreException implements Exception {
  const TokenStoreException.saveFailed([this.cause])
      : message = 'Could not save your session securely.';

  final Object? cause;
  final String message;

  @override
  String toString() => message;
}
