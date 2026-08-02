import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/auth/sign_in_flow.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/app_shell.dart';
import 'package:new_nutilize_mobile/services/supabase_service.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

/// Global map to store environment variables loaded from .env on desktop platforms
final globalEnv = <String, String>{};

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // On Windows desktop, rootBundle doesn't work. Read .env directly from the absolute path.
    final envPath = 'c:\\Users\\Joshueee\\new_nutilize_mobile\\.env';
    final envFile = File(envPath);
    if (envFile.existsSync()) {
      final contents = await envFile.readAsString();
      debugPrint('[main] .env file read successfully, size=${contents.length}');
      
      // Manually parse .env and populate globalEnv
      final lines = contents.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isNotEmpty && !trimmed.startsWith('#')) {
          final parts = trimmed.split('=');
          if (parts.length == 2) {
            globalEnv[parts[0]] = parts[1];
          }
        }
      }
      
      final anonKey = globalEnv['SUPABASE_ANON'];
      debugPrint('[main] Loaded SUPABASE_ANON length: ${anonKey?.length}');
      
      // Pass the environment to AuthService and SupabaseService
      AuthService.setEnvironment(globalEnv);
      SupabaseService.setEnvironment(globalEnv);
    } else {
      debugPrint('[main] .env file not found at $envPath');
    }
  } catch (e) {
    debugPrint('[main] .env load error: $e');
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
  runApp(const NUtilizeApp());
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
  if (userId != null) {
    final records = await ReservationService().getReservationRecordsForUser(userId);
    ReservationActivityStore.replaceAll(records);
  }
}

class NUtilizeApp extends StatelessWidget {
  const NUtilizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final hasSession = Supabase.instance.client.auth.currentSession != null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NUtilize',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF6C914)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: hasSession ? const AppShell() : const SignInFlowPage(),
    );
  }
}
