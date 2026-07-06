import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _baseUrl = 'https://uszlgigsuseomkwmqwan.supabase.co';
  static Map<String, dynamic>? currentUser;
  // Read anon/publishable key from a build-time environment variable so
  // it isn't checked into source control. Run the app with:
  //   flutter run --dart-define=SUPABASE_ANON="<anon_key>"
  // If the variable is not provided, the existing placeholder is used.
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON',
    defaultValue: 'sb_publishable_CAXPl0ysx7sNqAu-ms_m_A_9elijmPb',
  );

  // Sign up: prefer server-side function, fall back to legacy signup.
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? profile,
  }) async {
    final funcUrl = Uri.parse('$_baseUrl/functions/v1/register_user');
    final resp = await http.post(funcUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'profile': profile ?? {},
        }));

    // Success from function: treat any 200/201 as success and surface optional
    // session/access_token and any warning separately.
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body = jsonDecode(resp.body);
      final session = body['session'];
      final warning = body['warning'] ?? body['message'] ?? body['details'];
      if (session != null && session['access_token'] != null) {
        return {'error': null, 'access_token': session['access_token'], 'warning': warning};
      }

      final fallbackToken = await signIn(email: email, password: password);
      if (fallbackToken != null) {
        return {'error': null, 'access_token': fallbackToken, 'warning': null};
      }

      return {'error': null, 'access_token': null, 'warning': warning};
    }

    // Fallback to legacy signup if function missing
    final bodyText = resp.body;
    if (resp.statusCode == 404 || bodyText.contains('Requested function was not found')) {
      final legacyErr = await _legacySignUp(email: email, password: password, profile: profile);
      if (legacyErr != null) return {'error': legacyErr, 'access_token': null};
      // try to sign in to get token
      final token = await signIn(email: email, password: password);
      return {'error': null, 'access_token': token};
    }

    try {
      final body = jsonDecode(resp.body);
      final msg = body['message']?.toString() ?? body['error']?.toString() ?? 'Status ${resp.statusCode}';
      return {'error': msg, 'access_token': null};
    } catch (_) {
      return {'error': 'Status ${resp.statusCode}: ${resp.body}', 'access_token': null};
    }
  }

  // Legacy client-side signup fallback.
  static Future<String?> _legacySignUp({
    required String email,
    required String password,
    Map<String, dynamic>? profile,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/v1/signup');

    final resp = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body = jsonDecode(resp.body);
      String? accessToken = body['access_token'] ?? body['accessToken'];

      Map<String, dynamic>? profileToInsert;
      if (profile != null) {
        profileToInsert = Map<String, dynamic>.from(profile);
        profileToInsert.putIfAbsent('username', () => email);
        profileToInsert.putIfAbsent('password', () => password);
      }

      if (accessToken == null && profileToInsert != null) {
        accessToken = await signIn(email: email, password: password);
      }

      if (accessToken != null && profileToInsert != null) {
        final insertErr = await _insertProfile(accessToken, profileToInsert);
        if (insertErr != null) return 'Registered but failed saving profile: $insertErr';
      }

      return null;
    }

    try {
      final body = jsonDecode(resp.body);
      return body['message']?.toString() ?? body['error']?.toString() ?? 'Status ${resp.statusCode}';
    } catch (_) {
      return 'Status ${resp.statusCode}: ${resp.body}';
    }
  }

  // Sign in using the custom users table first, then fall back to Supabase Auth.
  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    currentUser = null;
    try {
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = authResponse.session;
      if (session == null) {
        return null;
      }

      final profile = await _fetchUserProfile(
        email: email,
        accessToken: session.accessToken,
      );
      currentUser = profile ?? {
        'email': email,
        'user_id': session.user.id,
      };
      return session.accessToken;
    } on AuthException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // Restore the current signed-in user from a persisted Supabase session.
  static Future<Map<String, dynamic>?> restoreCurrentUser() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      currentUser = null;
      return null;
    }

    final profile = await _fetchUserProfile(
      email: session.user.email ?? '',
      accessToken: session.accessToken,
    );
    currentUser = profile ?? {
      'email': session.user.email,
      'user_id': session.user.id,
    };
    return currentUser;
  }

  // Clear the current session and cached user.
  static Future<void> signOut() async {
    currentUser = null;
    await Supabase.instance.client.auth.signOut();
  }

  // Load the profile row for the signed-in user.
  static Future<Map<String, dynamic>?> _fetchUserProfile({
    required String email,
    required String accessToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/rest/v1/users?select=user_id,email,username,role&email=eq.${Uri.encodeQueryComponent(email)}&limit=1',
    );

    final resp = await http.get(
      url,
      headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $accessToken',
        'Accept': 'application/json',
      },
    );

    if (resp.statusCode != 200) {
      return null;
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List || decoded.isEmpty) {
      return null;
    }

    final user = Map<String, dynamic>.from(decoded.first as Map);
    return {
      'user_id': user['user_id'],
      'email': user['email'],
      'username': user['username'],
      'role': user['role'],
    };
  }

  // Inserts a profile row into `users`. Returns null on success or an error
  // message on failure.
  static Future<String?> _insertProfile(String accessToken, Map<String, dynamic> profile) async {
    final url = Uri.parse('$_baseUrl/rest/v1/users');

    final resp = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $accessToken',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(profile));

    if (resp.statusCode == 201 || resp.statusCode == 200) {
      return null;
    }

    try {
      final body = jsonDecode(resp.body);
      return body['message']?.toString() ?? body['error']?.toString() ?? 'Status ${resp.statusCode}';
    } catch (_) {
      return 'Status ${resp.statusCode}: ${resp.body}';
    }
  }

  // Request server to send a 6-digit verification code to the provided email.
  static Future<String?> sendEmailCode(String email) async {
    final funcUrl = Uri.parse('$_baseUrl/functions/v1/send_email_code');
    final resp = await http.post(funcUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({'email': email}));

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      return null;
    }

    try {
      final body = jsonDecode(resp.body);
      return body['message']?.toString() ?? body['error']?.toString() ?? 'Status ${resp.statusCode}';
    } catch (_) {
      return 'Status ${resp.statusCode}: ${resp.body}';
    }
  }

  // Verify a code previously sent to the email. Expects `verify_email_code` function.
  static Future<bool> verifyEmailCode(String email, String code) async {
    final funcUrl = Uri.parse('$_baseUrl/functions/v1/verify_email_code');
    final resp = await http.post(funcUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
        },
        body: jsonEncode({'email': email, 'code': code}));

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return body['ok'] == true;
    }
    return false;
  }
}
