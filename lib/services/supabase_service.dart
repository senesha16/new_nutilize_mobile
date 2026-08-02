import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static Map<String, String> _envVars = <String, String>{};

  static String get supabaseUrl {
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

    return String.fromEnvironment(
      'SUPABASE_ANON',
      defaultValue: '',
    );
  }

  static String get serviceRoleKey {
    if (_envVars.containsKey('SUPABASE_SERVICE_ROLE_KEY')) {
      final value = _envVars['SUPABASE_SERVICE_ROLE_KEY']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    try {
      final value = dotenv.env['SUPABASE_SERVICE_ROLE_KEY']?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    } catch (_) {}

    return String.fromEnvironment(
      'SUPABASE_SERVICE_ROLE_KEY',
      defaultValue: '',
    );
  }

  /// Call this from main.dart to pass environment variables
  static void setEnvironment(Map<String, String> env) {
    _envVars = env;
    debugPrint('[SupabaseService] Environment set');
  }

  static Future<void> init() async {
    final url = supabaseUrl;
    final key = supabaseKey;

    try {
      if (key.isEmpty) {
        await Supabase.initialize(
          url: url,
          anonKey: 'sb_publishable_dummy_key',
        );
        return;
      }

      await Supabase.initialize(
        url: url,
        anonKey: key,
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
        );
      } catch (_) {
        debugPrint('[SupabaseService] Second init attempt also failed, but proceeding');
      }
    }
  }

}
