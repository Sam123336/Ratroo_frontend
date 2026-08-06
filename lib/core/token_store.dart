import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens live in the OS keystore (Android EncryptedSharedPreferences / iOS
/// Keychain), never in SharedPreferences — a rooted device can read the latter
/// in plaintext.
class TokenStore {
  static const _accessKey = 'ratroo.accessToken';
  static const _refreshKey = 'ratroo.refreshToken';

  final FlutterSecureStorage _storage;

  // Defaults are already strong in flutter_secure_storage 11 (Android: AES-GCM
  // with RSA-OAEP key wrapping; iOS: Keychain). No options needed.
  TokenStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  /// Cached in memory so the request interceptor doesn't hit the keystore on
  /// every call — keystore reads are slow enough to be felt.
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;

    try {
      _accessToken = await _storage.read(key: _accessKey);
      _refreshToken = await _storage.read(key: _refreshKey);
    } catch (error) {
      // The keystore can be unavailable: MissingPluginException after adding the
      // plugin without a full rebuild, a locked device, or an unsupported
      // platform. Degrade to "signed out" — a storage problem must never break
      // public endpoints like search.
      debugPrint('TokenStore: secure storage unavailable, continuing signed out ($error)');
      _accessToken = null;
      _refreshToken = null;
    }

    _loaded = true;
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isSignedIn => _refreshToken != null;

  Future<void> save({required String accessToken, required String refreshToken}) async {
    // In-memory first: if persistence fails the session still works until the
    // app is killed, rather than the sign-in appearing to fail outright.
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _loaded = true;

    try {
      await _storage.write(key: _accessKey, value: accessToken);
      await _storage.write(key: _refreshKey, value: refreshToken);
    } catch (error) {
      debugPrint('TokenStore: could not persist tokens, session is memory-only ($error)');
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;

    try {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    } catch (error) {
      // In-memory tokens are already gone, which is what sign-out most needs.
      debugPrint('TokenStore: could not clear persisted tokens ($error)');
    }
  }
}
