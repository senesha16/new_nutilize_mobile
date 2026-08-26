import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/auth/sign_in_flow.dart';
import 'package:new_nutilize_mobile/widgets/app_shell.dart';
import 'package:new_nutilize_mobile/services/supabase_service.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

/// Global map to store environment variables loaded from .env on desktop platforms
final globalEnv = <String, String>{};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NUtilizeApp());
}

Future<void> _initializeApplication() async {
  // Try to load .env from assets (works on all platforms)
  try {
    await dotenv.load();  // No fileName - uses pubspec.yaml assets by default
    for (final entry in dotenv.env.entries) {
      globalEnv[entry.key] = entry.value;
    }

    final anonKey = globalEnv['SUPABASE_ANON'];
    debugPrint('[main] Loaded SUPABASE_ANON from assets, length: ${anonKey?.length}');

    AuthService.setEnvironment(globalEnv);
    SupabaseService.setEnvironment(globalEnv);
  } catch (e) {
    debugPrint('[main] .env asset load error: $e');

    // Fallback: try loading from Windows file path (for desktop development)
    try {
      final envPath = 'c:\\Users\\Joshueee\\new_nutilize_mobile\\.env';
      final envFile = File(envPath);
      if (envFile.existsSync()) {
        final contents = await envFile.readAsString();
        final lines = contents.split('\n');
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
            final parts = trimmed.split('=');
            if (parts.length >= 2) {
              globalEnv[parts[0]] = parts.sublist(1).join('=');
            }
          }
        }
        debugPrint('[main] Loaded .env from Windows fallback path');
        AuthService.setEnvironment(globalEnv);
        SupabaseService.setEnvironment(globalEnv);
      }
    } catch (e) {
      debugPrint('[main] Windows fallback also failed: $e');
    }
  }

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('[main] Supabase init error (continuing anyway): $e');
  }
  
  try {
    await _repairPersistedSession();
  } catch (e) {
    debugPrint('[main] Session repair error (continuing anyway): $e');
  }
}

Future<void> _repairPersistedSession() async {
  final auth = Supabase.instance.client.auth;
  final session = auth.currentSession;
  if (session == null) {
    return;
  }

  final profile = await AuthService.restoreCurrentUser();
  if (profile == null) {
    await AuthService.signOut();
    return;
  }

  final userId = profile['user_id'] is int
      ? profile['user_id'] as int
      : int.tryParse(profile['user_id']?.toString() ?? '');
  if (userId == null) {
    await AuthService.signOut();
  }
}

class NUtilizeApp extends StatelessWidget {
  const NUtilizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    bool hasSession = false;
    try {
      hasSession = Supabase.instance.client.auth.currentSession != null;
    } catch (_) {
      hasSession = false;
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NUtilize',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF6C914)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _isReady = false;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _initializeApplication();
      _hasSession = Supabase.instance.client.auth.currentSession != null;
    } catch (e) {
      debugPrint('[startup] Initialization error: $e');
      _hasSession = false;
    }
    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const _StartupSplash();
    }
    return _hasSession ? const AppShell() : const SignInFlowPage();
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF243C8F),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/nutilize_logo.png', width: 230),
              const SizedBox(height: 28),
              const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6C914)),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Loading NUtilize...',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
