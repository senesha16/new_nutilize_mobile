import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String supabaseUrl = 'https://uszlgigsuseomkwmqwan.supabase.co';
  // Replace with your anon/public key if you prefer to store elsewhere
  static const String supabaseKey = 'sb_publishable_CAXPl0ysx7sNqAu-ms_m_A_9elijmPb';

  static Future<void> init() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );
  }
}
