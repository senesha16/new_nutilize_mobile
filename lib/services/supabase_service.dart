import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SecureSessionStorage extends LocalStorage {
  _SecureSessionStorage()
      : super(
          initialize: _initialize,
          hasAccessToken: _hasAccessToken,
          accessToken: _accessToken,
          removePersistedSession: _removePersistedSession,
          persistSession: _persistSession,
        );

  static const _sessionKey = 'nutilize.supabase.session';
  static const _storage = FlutterSecureStorage();

  static Future<void> _initialize() async {}

  static Future<bool> _hasAccessToken() async {
    return (await _storage.read(key: _sessionKey)) != null;
  }

  static Future<String?> _accessToken() {
    return _storage.read(key: _sessionKey);
  }

  static Future<void> _removePersistedSession() {
    return _storage.delete(key: _sessionKey);
  }

  static Future<void> _persistSession(String session) {
    return _storage.write(key: _sessionKey, value: session);
  }
}

class SupabaseService {
  static Map<String, String> _envVars = <String, String>{};
  static const bool _securityTestMode = bool.fromEnvironment(
    'NUTILIZE_SECURITY_TEST',
    defaultValue: false,
  );

  static String get supabaseUrl {
    if (_securityTestMode) {
      return _envVars['SUPABASE_URL']?.trim() ?? '';
    }

    // First check _envVars
    if (_envVars.containsKey('SUPABASE_URL')) {
      final value = _envVars['SUPABASE_URL']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    try {
      final value = dotenv.env['SUPABASE_URL']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    } catch (_) {}

    return String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://uszlgigsuseomkwmqwan.supabase.co',
    );
  }

  // Read the anon/public key from runtime environment (dotenv or dart-define).
  static String get supabaseKey {
    if (_securityTestMode) {
      return _envVars['SUPABASE_ANON']?.trim() ?? '';
    }

    // First check _envVars
    if (_envVars.containsKey('SUPABASE_ANON')) {
      final value = _envVars['SUPABASE_ANON']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    try {
      final value = dotenv.env['SUPABASE_ANON']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    } catch (_) {}

    return String.fromEnvironment('SUPABASE_ANON', defaultValue: '');
  }

  static String get serviceRoleKey {
    // A service-role key must never be shipped in a client application.
    return '';
  }

  /// Call this from main.dart to pass environment variables
  static void setEnvironment(Map<String, String> env) {
    _envVars = env;
    debugPrint('[SupabaseService] Environment set');
  }

  static Future<void> init() async {
    final url = supabaseUrl;
    final key = supabaseKey;
    final localStorage = _securityTestMode
      ? const EmptyLocalStorage()
      : _SecureSessionStorage();

    try {
      if (key.isEmpty) {
        await Supabase.initialize(
          url: url,
          anonKey: 'sb_publishable_dummy_key',
          localStorage: localStorage,
          debug: false,
        );
        return;
      }

      await Supabase.initialize(
        url: url,
        anonKey: key,
        localStorage: localStorage,
        debug: false,
      );
    } on Exception catch (e) {
      debugPrint('[SupabaseService] Init error (continuing anyway): $e');
      // Try one more time without local storage configuration
      // On desktop, Hive local storage can cause lock conflicts
      // For now, we'll accept the partial initialization
      try {
        await Supabase.initialize(
          url: url,
          anonKey: key,
          localStorage: localStorage,
          debug: false,
        );
      } catch (_) {
        debugPrint(
          '[SupabaseService] Second init attempt also failed, but proceeding',
        );
      }
    }
  }
}
