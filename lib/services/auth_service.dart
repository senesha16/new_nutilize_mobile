import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/supabase_service.dart';

class AuthService {
  static String get _baseUrl => SupabaseService.supabaseUrl;
  static Map<String, dynamic>? currentUser;
  static String? lastAuthError;
  static Map<String, String> _envVars = <String, String>{};  // Store env from main.dart
  static const Map<String, int> _programIdByAffiliation = {
    'b multimedia arts': 1,
    'bs architecture': 2,
    'bs civil engineering': 3,
    'bs computer science': 4,
    'bs computer engineering': 5,
    'bs information technology': 6,
    'bs information technology with specialization in mobile and web applications': 6,
    'bs accountancy': 7,
    'bsba major in financial management': 8,
    'bsba major in marketing management': 9,
    'bs management accounting': 10,
    'bs tourism management': 11,
    'bs psychology': 12,
    'bs medical technology': 13,
    'bs nursing': 14,
  };

  static String? _normalizeAffiliation(String? affiliation) {
    final value = affiliation?.trim().toLowerCase();
    return (value == null || value.isEmpty) ? null : value;
  }

  static const String itSpecializationLabel =
      'BS Information Technology with specialization in Mobile and Web Applications';

  static int? programIdForAffiliation(String? affiliation) {
    final normalized = _normalizeAffiliation(affiliation);
    if (normalized == null) return null;
    return _programIdByAffiliation[normalized];
  }

  static Map<String, dynamic>? normalizeProfile(Map<String, dynamic>? profile) {
    if (profile == null) return null;
    final normalized = Map<String, dynamic>.from(profile);
    normalized.remove('password');
    normalized.remove('confirm_password');
    final programId = normalized['program_id'];
    if (programId == null) {
      final mappedProgramId = programIdForAffiliation(normalized['affiliation']?.toString());
      if (mappedProgramId != null) {
        normalized['program_id'] = mappedProgramId;
      }
    }
    return normalized;
  }
  // Read anon/publishable key from a build-time environment variable so
  // it isn't checked into source control. Run the app with:
  //   flutter run --dart-define=SUPABASE_ANON="<anon_key>"
  // If the variable is not provided, the existing placeholder is used.
  static String get _anonKey {
    // First, check the environment variables passed from main.dart
    if (_envVars.containsKey('SUPABASE_ANON')) {
      final value = _envVars['SUPABASE_ANON']?.trim();
      if (value != null && value.isNotEmpty) {
        debugPrint('[AuthService] Using SUPABASE_ANON from _envVars, length=${value.length}');
        return value;
      }
    }

    // Then try dotenv
    try {
      final value = dotenv.env['SUPABASE_ANON']?.trim();
      debugPrint('[AuthService] dotenv.env[SUPABASE_ANON] = ${value?.substring(0, 20) ?? 'null'}...');
      if (value != null && value.isNotEmpty) {
        return value;
      }
    } catch (e) {
      debugPrint('[AuthService] Error reading dotenv: $e');
    }

    // Finally, fall back to dart-define
    final fallback = String.fromEnvironment('SUPABASE_ANON', defaultValue: '');
    debugPrint('[AuthService] Using dart-define fallback, length=${fallback.length}');
    return fallback;
  }

  /// Call this from main.dart to pass environment variables
  static void setEnvironment(Map<String, String> env) {
    _envVars = env;
    debugPrint('[AuthService] Environment set with keys: ${env.keys.join(', ')}');
  }

  static bool get _hasValidAnonKey {
    final key = _anonKey;
    final isValid = key.isNotEmpty && !key.contains('dummy');
    debugPrint('[AuthService] Checking anon key: length=${key.length}, contains_dummy=${key.contains('dummy')}, valid=$isValid');
    return isValid;
  }


  static void _setLastAuthError(String? error) {
    lastAuthError = error;
    if (error != null) {
      debugPrint('[AuthService] $error');
    }
  }

  // Sign up: prefer server-side function, fall back to legacy signup.
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? profile,
  }) async {
    if (!_hasValidAnonKey) {
      return {
        'error': 'Missing SUPABASE_ANON. Create a .env file or pass --dart-define=SUPABASE_ANON=<anon_key> before running the app.',
        'access_token': null,
      };
    }

    final normalizedProfile = normalizeProfile(profile) ?? {};
    final funcUrl = Uri.parse('$_baseUrl/functions/v1/register_user');
    
    final requestBody = {
      'email': email,
      'password': password,
      'affiliation': normalizedProfile['affiliation'],
      'program_id': normalizedProfile['program_id'],
      'profile': normalizedProfile,
    };
    final bodyStr = jsonEncode(requestBody);
    
    debugPrint('[AuthService] Sending signup request to: $funcUrl');
    debugPrint('[AuthService] Request body length: ${bodyStr.length}');
    debugPrint('[AuthService] Request body: $bodyStr');
    
    final resp = await http.post(funcUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: bodyStr);
    
    debugPrint('[AuthService] Signup response status: ${resp.statusCode}');
    debugPrint('[AuthService] Signup response body: ${resp.body}');

    // Success from function: treat any 200/201 as success and return the
    // session token if available. The function already inserts the profile,
    // so no additional profile writes are needed here.
    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final body = jsonDecode(resp.body);
      final session = body['session'];
      final warning = body['warning'] ?? body['message'] ?? body['details'];
      
      // If session was created by the function, use it
      if (session != null && session['access_token'] != null) {
        final refreshToken = session['refresh_token']?.toString();
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await _restoreSession(refreshToken);
        }
        return {
          'error': null,
          'access_token': session['access_token'],
          'refresh_token': refreshToken,
          'warning': warning,
        };
      }

      // Registration succeeded but the function did not create a session.
      // Try one fast sign-in immediately so the user still gets a session.
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final fallbackToken = await signIn(email: email, password: password);
      if (fallbackToken != null) {
        debugPrint('[AuthService] Fast sign-in succeeded after registration.');
        return {
          'error': null,
          'access_token': fallbackToken,
          'warning': warning ?? 'Account created and signed in.',
        };
      }

      debugPrint('[AuthService] Fast sign-in after registration failed; user can log in manually.');
      return {
        'error': null,
        'access_token': null,
        'warning': warning ?? 'Account created! Please log in with your credentials.',
      };
    }

    // Fallback to legacy signup if function missing
    final bodyText = resp.body;
    if (resp.statusCode == 404 || bodyText.contains('Requested function was not found')) {
      final legacyErr = await _legacySignUp(email: email, password: password, profile: normalizedProfile);
      if (legacyErr != null) return {'error': legacyErr, 'access_token': null};
      // try to sign in to get token
      final token = await _passwordGrantWithRetry(email: email, password: password);
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
    final normalizedProfile = normalizeProfile(profile);
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
      if (normalizedProfile != null) {
        profileToInsert = Map<String, dynamic>.from(normalizedProfile);
        profileToInsert.putIfAbsent('username', () => email);
      }

      if (accessToken == null && profileToInsert != null) {
        accessToken = await _signInWithRetry(email: email, password: password);
      }

      if (accessToken != null && profileToInsert != null) {
        final insertErr = await _insertProfile(accessToken, profileToInsert);
        if (insertErr != null) return 'Registered but failed saving profile: $insertErr';
        await _ensureRegistrationProfile(
          email: email,
          accessToken: accessToken,
          profile: profileToInsert,
        );
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
    _setLastAuthError(null);

    final normalizedEmail = email.trim();

    if (!_hasValidAnonKey) {
      _setLastAuthError('Supabase anon key is missing or still using a placeholder. Open the project root and put your real anon key in .env as SUPABASE_ANON=...');
      debugPrint('[AuthService] signIn: anon key missing');
      return null;
    }

    debugPrint('[AuthService] signIn: attempting for $normalizedEmail');

    // TEMPORARY: Log but don't block on email validation to diagnose Supabase connectivity
    // The email validation was returning false due to RLS permissions, blocking all logins
    // TODO: Fix RLS policies on users table so anon key can read emails
    try {
      unawaited(_validateEmailCaseSensitivity(normalizedEmail).then((valid) {
        debugPrint('[AuthService] Email validation result (non-blocking): $valid for $normalizedEmail');
      }));
    } catch (e) {
      debugPrint('[AuthService] Email validation error (caught, non-blocking): $e');
    }

    debugPrint('[AuthService] signIn: using Supabase URL $_baseUrl');
    debugPrint('[AuthService] signIn: bypassing email validation check, attempting Supabase auth directly');

    try {
      debugPrint('[AuthService] signIn: calling Supabase.instance.client.auth.signInWithPassword for $normalizedEmail');
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final session = authResponse.session;
      if (session == null) {
        debugPrint('[AuthService] signIn: no session from Supabase, attempting recovery');
        return await _recoverLoginWithEdgeFunction(email: email, password: password);
      }
      debugPrint('[AuthService] signIn: Supabase auth success, session obtained');

      final profile = await _fetchUserProfile(
        email: email,
        accessToken: session.accessToken,
      );
      if (profile != null) {
        await _repairProgramIdIfNeeded(
          email: email,
          accessToken: session.accessToken,
          profile: profile,
        );
      }
      currentUser = profile ?? {
        'email': email,
        'user_id': null,
        'auth_user_id': session.user.id,
      };
      debugPrint('[AuthService] signIn: success for $normalizedEmail');
      return session.accessToken;
    } on AuthException catch (e) {
      debugPrint('[AuthService] signIn: AuthException: ${e.message}');
      _setLastAuthError(e.message);
      final recovered = await _recoverLoginWithEdgeFunction(email: email, password: password);
      if (recovered != null) {
        return recovered;
      }
      return await _loginWithLegacyUsersTable(email: email, password: password);
    } catch (e) {
      debugPrint('[AuthService] signIn: exception: $e');
      _setLastAuthError(e.toString());
      final recovered = await _recoverLoginWithEdgeFunction(email: email, password: password);
      if (recovered != null) {
        return recovered;
      }
      return await _loginWithLegacyUsersTable(email: email, password: password);
    }
  }

  static Future<String?> _signInWithRetry({
    required String email,
    required String password,
  }) async {
    const delays = [
      Duration(milliseconds: 0),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 12),
      Duration(seconds: 16),
    ];

    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final token = await signIn(email: email, password: password);
      if (token != null) {
        return token;
      }
    }

    return null;
  }

  static Future<String?> _passwordGrantWithRetry({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('$_baseUrl/auth/v1/token?grant_type=password');
    final resp = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
      },
      body: jsonEncode({
        'grant_type': 'password',
        'email': email,
        'password': password,
      }),
    );

    if (resp.statusCode == 200) {
      try {
        final body = jsonDecode(resp.body);
        final accessToken = body['access_token']?.toString();
        final refreshToken = body['refresh_token']?.toString();
        if (accessToken != null && accessToken.isNotEmpty && refreshToken != null && refreshToken.isNotEmpty) {
          try {
            await Supabase.instance.client.auth.setSession(refreshToken);
            return accessToken;
          } catch (_) {
            _setLastAuthError('Session restore failed after token retrieval.');
            return null;
          }
        }
      } catch (e) {
        _setLastAuthError('Invalid login response: ${e.toString()}');
        return null;
      }
    } else {
      try {
        final body = jsonDecode(resp.body);
        _setLastAuthError(body['msg']?.toString() ?? body['message']?.toString() ?? body['error_description']?.toString() ?? body['error']?.toString() ?? 'Login failed with status ${resp.statusCode}');
      } catch (_) {
        _setLastAuthError('Login failed with status ${resp.statusCode}');
      }
    }

    return null;
  }

  static Future<String?> _recoverLoginWithEdgeFunction({
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthService] Attempting edge-function login recovery for $email');
    final funcUrl = Uri.parse('$_baseUrl/functions/v1/register_user');
    final resp = await http.post(
      funcUrl,
      headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'affiliation': 'student',
        'program_id': 1,
        'profile': {'email': email, 'affiliation': 'student', 'program_id': 1},
      }),
    );

    debugPrint('[AuthService] Edge-function login recovery status: ${resp.statusCode}');
    debugPrint('[AuthService] Edge-function login recovery body: ${resp.body}');

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      try {
        final body = jsonDecode(resp.body);
        final session = body['session'];
        final token = session?['access_token']?.toString() ?? body['access_token']?.toString();
        if (token != null && token.isNotEmpty) {
          final refreshToken = session?['refresh_token']?.toString();
          if (refreshToken != null && refreshToken.isNotEmpty) {
            await _restoreSession(refreshToken);
          }
          return token;
        }
      } catch (_) {}
    }

    return _loginWithLegacyUsersTable(email: email, password: password);
  }

  static Future<String?> _loginWithLegacyUsersTable({
    required String email,
    required String password,
  }) async {
    debugPrint('[AuthService] _loginWithLegacyUsersTable: attempting legacy auth for $email');
    final url = Uri.parse(
      '$_baseUrl/rest/v1/users?select=user_id,email,username,role,affiliation,program_id,password&email=eq.${Uri.encodeQueryComponent(email)}&limit=1',
    );

    debugPrint('[AuthService] _loginWithLegacyUsersTable: querying public.users table');
    final resp = await http.get(
      url,
      headers: {
        'apikey': _anonKey,
        'Authorization': 'Bearer $_anonKey',
        'Accept': 'application/json',
      },
    );

    debugPrint('[AuthService] _loginWithLegacyUsersTable: query status ${resp.statusCode}');
    if (resp.statusCode != 200) {
      debugPrint('[AuthService] _loginWithLegacyUsersTable: query failed with status ${resp.statusCode}, body: ${resp.body}');
      return null;
    }

    try {
      final decoded = jsonDecode(resp.body);
      debugPrint('[AuthService] _loginWithLegacyUsersTable: decoded response type ${decoded.runtimeType}');
      if (decoded is! List || decoded.isEmpty) {
        debugPrint('[AuthService] _loginWithLegacyUsersTable: no users found for $email');
        return null;
      }

      final row = Map<String, dynamic>.from(decoded.first as Map);
      final storedPassword = row['password']?.toString();
      debugPrint('[AuthService] _loginWithLegacyUsersTable: found user, checking password');
      
      if (storedPassword == null || storedPassword != password) {
        debugPrint('[AuthService] _loginWithLegacyUsersTable: password mismatch');
        return null;
      }

      debugPrint('[AuthService] _loginWithLegacyUsersTable: password matches! Setting currentUser');
      currentUser = {
        'user_id': row['user_id'],
        'email': row['email'] ?? email,
        'username': row['username'] ?? email,
        'role': row['role'],
        'affiliation': row['affiliation'],
        'program_id': row['program_id'],
      };
      _setLastAuthError(null);

      final sessionToken = await _passwordGrantWithRetry(email: email, password: password);
      if (sessionToken != null) {
        debugPrint('[AuthService] _loginWithLegacyUsersTable: got session token from password grant');
        return sessionToken;
      }

      debugPrint('[AuthService] _loginWithLegacyUsersTable: returning legacy session token');
      return 'legacy-session:${email}';
    } catch (e) {
      debugPrint('[AuthService] _loginWithLegacyUsersTable: exception: $e');
      return null;
    }
  }

  static Future<String?> _signInWithPasswordGrant({
    required String email,
    required String password,
  }) async {
    final token = await _passwordGrantWithRetry(email: email, password: password);
    if (token == null) {
      return null;
    }

    final session = Supabase.instance.client.auth.currentSession;
    final accessToken = session?.accessToken ?? token;
    final profile = await _fetchUserProfile(
      email: email,
      accessToken: accessToken,
    );
    if (profile != null) {
      await _repairProgramIdIfNeeded(
        email: email,
        accessToken: accessToken,
        profile: profile,
      );
    }

    currentUser = profile ?? {
      'email': email,
      'user_id': null,
      'auth_user_id': Supabase.instance.client.auth.currentSession?.user.id,
    };
    return token;
  }

  static Future<bool> _restoreSession(String refreshToken) async {
    try {
      await Supabase.instance.client.auth.setSession(refreshToken);
      await restoreCurrentUser();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> _ensureRegistrationProfile({
    required String email,
    required String accessToken,
    required Map<String, dynamic> profile,
  }) async {
    final payload = <String, dynamic>{};
    final affiliation = profile['affiliation']?.toString().trim();
    final programId = profile['program_id'];

    if (affiliation != null && affiliation.isNotEmpty) {
      payload['affiliation'] = affiliation;
    }
    if (programId != null) {
      payload['program_id'] = programId is int ? programId : int.tryParse(programId.toString());
    }
    if (payload['program_id'] == null && affiliation != null && affiliation.isNotEmpty) {
      final mappedProgramId = programIdForAffiliation(affiliation);
      if (mappedProgramId != null) {
        payload['program_id'] = mappedProgramId;
      }
    }

    if (payload['program_id'] == null) {
      return 'Missing program_id for $email';
    }

    final url = Uri.parse('$_baseUrl/rest/v1/users?email=eq.${Uri.encodeQueryComponent(email)}');
    final resp = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'apikey': _anonKey,
        'Authorization': 'Bearer $accessToken',
        'Prefer': 'return=representation',
      },
      body: jsonEncode(payload),
    );

    if (resp.statusCode == 200 || resp.statusCode == 204) {
      return null;
    }

    return 'Status ${resp.statusCode}: ${resp.body}';
  }

  static Future<void> _repairProgramIdIfNeeded({
    required String email,
    required String accessToken,
    required Map<String, dynamic> profile,
  }) async {
    final existingProgramId = profile['program_id'];
    if (existingProgramId != null) {
      return;
    }

    final affiliation = profile['affiliation']?.toString();
    if (affiliation == null || affiliation.trim().isEmpty) {
      return;
    }

    final mappedProgramId = programIdForAffiliation(affiliation);
    if (mappedProgramId == null) {
      return;
    }

    await _ensureRegistrationProfile(
      email: email,
      accessToken: accessToken,
      profile: {
        ...profile,
        'program_id': mappedProgramId,
      },
    );
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
    if (profile != null) {
      await _repairProgramIdIfNeeded(
        email: session.user.email ?? '',
        accessToken: session.accessToken,
        profile: profile,
      );
    }
    currentUser = profile ?? {
      'email': session.user.email,
      'user_id': null,
      'auth_user_id': session.user.id,
    };
    return currentUser;
  }

  // Clear the current session and cached user.
  static Future<void> signOut() async {
    currentUser = null;
    ReservationActivityStore.clear();
    await Supabase.instance.client.auth.signOut();
  }

  // Load the profile row for the signed-in user.
  // Treat email matching as case-insensitive so users do not get false
  // "Invalid credentials" failures when the row is stored with a different case.
  static Future<bool> _validateEmailCaseSensitivity(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      debugPrint('[AuthService] _validateEmailCaseSensitivity: empty email');
      return false;
    }

    try {
      final url = Uri.parse(
        '$_baseUrl/rest/v1/users?select=email&limit=10000',
      );

      debugPrint('[AuthService] _validateEmailCaseSensitivity: querying users table');

      final resp = await http.get(
        url,
        headers: {
          'apikey': _anonKey,
          'Accept': 'application/json',
        },
      );

      debugPrint('[AuthService] _validateEmailCaseSensitivity: response status ${resp.statusCode}');

      if (resp.statusCode != 200) {
        debugPrint('[AuthService] _validateEmailCaseSensitivity: query failed with status ${resp.statusCode}');
        debugPrint('[AuthService] _validateEmailCaseSensitivity: response body: ${resp.body}');
        return false;
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        debugPrint('[AuthService] _validateEmailCaseSensitivity: response is not a list');
        return false;
      }

      debugPrint('[AuthService] _validateEmailCaseSensitivity: checking ${decoded.length} users');

      for (final user in decoded) {
        if (user is Map) {
          final storedEmail = user['email']?.toString();
          if (storedEmail != null && storedEmail.toLowerCase() == normalizedEmail.toLowerCase()) {
            debugPrint('[AuthService] _validateEmailCaseSensitivity: found matching email');
            return true;
          }
        }
      }

      debugPrint('[AuthService] _validateEmailCaseSensitivity: no matching email found for $normalizedEmail');
      return false;
    } catch (e) {
      debugPrint('[AuthService] _validateEmailCaseSensitivity error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> _fetchUserProfile({
    required String email,
    required String accessToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/rest/v1/users?select=user_id,email,username,role,affiliation,program_id&email=eq.${Uri.encodeQueryComponent(email)}&limit=1',
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
      'affiliation': user['affiliation'],
      'program_id': user['program_id'],
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
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      return 'Please enter your email.';
    }

    if (!_hasValidAnonKey) {
      debugPrint('[AuthService] sendEmailCode: anon key is invalid or missing');
      return 'Supabase anonymous key is missing. Check your .env values.';
    }

    final funcUrl = Uri.parse('$_baseUrl/functions/v1/send_email_code');
    debugPrint('[AuthService] sendEmailCode: calling $funcUrl for $normalizedEmail');
    debugPrint('[AuthService] sendEmailCode: using anon key = ${_anonKey.substring(0, 20)}...');

    try {
      final resp = await http.post(
        funcUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: jsonEncode({'email': normalizedEmail}),
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Edge function request timed out after 10 seconds');
      });

      debugPrint('[AuthService] sendEmailCode response: status=${resp.statusCode}');
      debugPrint('[AuthService] sendEmailCode response headers: ${resp.headers}');
      debugPrint('[AuthService] sendEmailCode response body: ${resp.body}');

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        debugPrint('[AuthService] sendEmailCode: success');
        return null;
      }

      try {
        final body = jsonDecode(resp.body);
        final msg = body['message']?.toString() ??
            body['error']?.toString() ??
            body['details']?.toString() ??
            'HTTP ${resp.statusCode}';
        debugPrint('[AuthService] sendEmailCode: API error = $msg');
        return msg;
      } catch (_) {
        final errorMsg = 'HTTP ${resp.statusCode}: ${resp.body}';
        debugPrint('[AuthService] sendEmailCode: parse error = $errorMsg');
        return errorMsg;
      }
    } catch (e, st) {
      debugPrint('[AuthService] sendEmailCode exception: $e');
      debugPrint('[AuthService] sendEmailCode stack: $st');
      return 'Edge function error: $e';
    }
  }

  // Verify a code previously sent to the email. Expects `verify_email_code` function.
  static Future<bool> verifyEmailCode(String email, String code) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty || code.trim().isEmpty) {
      return false;
    }

    try {
      final funcUrl = Uri.parse('$_baseUrl/functions/v1/verify_email_code');
      final resp = await http.post(
        funcUrl,
        headers: {
          'Content-Type': 'application/json',
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: jsonEncode({'email': normalizedEmail, 'code': code.trim()}),
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return body['ok'] == true;
      }

      debugPrint('[AuthService] verifyEmailCode failed: ${resp.statusCode} ${resp.body}');
      return false;
    } catch (e) {
      debugPrint('[AuthService] verifyEmailCode exception: $e');
      return false;
    }
  }
}
