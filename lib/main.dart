import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/auth/sign_in_flow.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/app_shell.dart';
import 'package:new_nutilize_mobile/services/supabase_service.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  await _repairPersistedSession();
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

  final userId = profile['user_id'] as int?;
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
