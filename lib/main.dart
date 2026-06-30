import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:new_nutilize_mobile/features/auth/sign_in_flow.dart';

void main() {
  runApp(const NUtilizeApp());
}

class NUtilizeApp extends StatelessWidget {
  const NUtilizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NUtilize',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF6C914)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: GoogleFonts.poppinsTextTheme(),
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      home: const SignInFlowPage(),
    );
  }
}
