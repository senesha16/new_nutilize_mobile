import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:new_nutilize_mobile/features/auth/loading_screen_page.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/app_shell.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

enum SignInStep {
  login,

  // Registration
  email,
  code,
  role,
  profile,
  setPassword,

  // Login
  loginEmail,
  loginCode,
}

class SignInFlowPage extends StatefulWidget {
  const SignInFlowPage({super.key});

  @override
  State<SignInFlowPage> createState() => _SignInFlowPageState();
}

class _SignInFlowPageState extends State<SignInFlowPage> {
  static const String backgroundAsset = 'assets/images/nutilize_bg.jpg';
  static const String logoAsset = 'assets/images/nutilize_logo.png';

  static const List<_ProgramOption> _programOptions = [
    _ProgramOption(id: 1, label: 'B Multimedia Arts'),
    _ProgramOption(id: 2, label: 'BS Architecture'),
    _ProgramOption(id: 3, label: 'BS Civil Engineering'),
    _ProgramOption(id: 4, label: 'BS Computer Science'),
    _ProgramOption(id: 5, label: 'BS Computer Engineering'),
    _ProgramOption(id: 6, label: 'BS Information Technology with specialization in Mobile and Web Applications'),
    _ProgramOption(id: 7, label: 'BS Accountancy'),
    _ProgramOption(id: 8, label: 'BSBA Major in Financial Management'),
    _ProgramOption(id: 9, label: 'BSBA Major in Marketing Management'),
    _ProgramOption(id: 10, label: 'BS Management Accounting'),
    _ProgramOption(id: 11, label: 'BS Tourism Management'),
    _ProgramOption(id: 12, label: 'BS Psychology'),
    _ProgramOption(id: 13, label: 'BS Medical Technology'),
    _ProgramOption(id: 14, label: 'BS Nursing'),
  ];

  List<DropdownMenuItem<String?>> _buildProgramDropdownItems() {
    return [
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('Select your department'),
      ),
      for (final option in _programOptions)
        DropdownMenuItem<String?>(
          value: option.label,
          child: Text(option.label),
        ),
    ];
  }

  SignInStep _step = SignInStep.login;
  String _selectedRole = 'Student';
  String? _selectedDepartment;
  int? _selectedProgramId;
  File? _selectedImage;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactNumberController = TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codeFocusNodes = List.generate(
    6,
    (_) => FocusNode(),
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _contactNumberController.dispose();
    for (final controller in _codeControllers) {
      controller.dispose();
    }
    for (final node in _codeFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool _isLoggingIn = false;

  Future<void> _attemptLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() {
      _isLoggingIn = true;
    });

    try {
      final token = await AuthService.signIn(email: email, password: password);
      if (token != null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final userId = AuthService.currentUser?['user_id'] as int?;
        if (userId != null) {
          final records = await ReservationService().getReservationRecordsForUser(userId);
          ReservationActivityStore.replaceAll(records);
        }
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      } else {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final error = AuthService.lastAuthError ?? 'Login failed. Check credentials.';
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    } catch (e) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      if (mounted && _step == SignInStep.loginEmail) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  bool _isSavingAccount = false;

  Future<void> _attemptSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill required fields')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    final affiliation = _selectedDepartment?.trim();
    if (affiliation == null || affiliation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your program before creating your account.')),
      );
      return;
    }

    final programId = _selectedProgramId ?? AuthService.programIdForAffiliation(affiliation);
    if (programId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid program before creating your account.')),
      );
      return;
    }

    setState(() {
      _isSavingAccount = true;
    });

    try {
      final profile = {
        'email': email,
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'contact_number': _contactNumberController.text.trim(),
        'role': _selectedRole,
        'affiliation': affiliation,
        'program_id': programId,
      };

      final result = await AuthService.signUp(email: email, password: password, profile: profile);
      final error = result['error'] as String?;

      if (error == null) {
        final warning = result['warning'] as String?;
        if (warning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✓ $warning')),
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Account created. Please log in to continue.')),
        );

        _goToStep(SignInStep.loginEmail);
        _emailController.text = email;
        _passwordController.clear();
        _confirmPasswordController.clear();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAccount = false;
        });
      }
    }
  }

  void _goToStep(SignInStep step) {
    setState(() {
      _step = step;
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundAsset),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF223A8E).withValues(alpha: 0.58),
                const Color(0xFF1C2D75).withValues(alpha: 0.75),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_step == SignInStep.login) ...[
                        const Text(
                          'Welcome to',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Image.asset(logoAsset, width: 240, fit: BoxFit.contain),
                        const SizedBox(height: 28),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _buildStepCard(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard() {
    switch (_step) {
      case SignInStep.login:
        return _AuthCard(
          key: const ValueKey('login'),
          child: Column(
            children: [
              _PrimaryButton(
                label: 'LOG IN',
                onPressed: () => _goToStep(SignInStep.loginEmail),
              ),

              const SizedBox(height: 20),

              Row(
                children: const [
                  Expanded(child: Divider(color: Colors.white54, thickness: 1)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white54, thickness: 1)),
                ],
              ),

              const SizedBox(height: 20),

              _MicrosoftButton(
                label: 'Register with Microsoft',
                onPressed: () => _goToStep(SignInStep.email),
              ),
            ],
          ),
        );

      case SignInStep.loginEmail:
        return _AuthCard(
          key: const ValueKey('loginEmail'),
          title: 'Log In',
          subtitle: 'Enter your email and password.',
          onBack: () => _goToStep(SignInStep.login),
          child: Column(
            children: [
              _InputField(
                controller: _emailController,
                hintText: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
                prefix: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFFF6C914),
                ),
              ),

              const SizedBox(height: 14),

              _InputField(
                controller: _passwordController,
                hintText: 'Enter your password',
                obscureText: true,
                prefix: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFF6C914),
                ),
              ),

              const SizedBox(height: 20),

              if (_isLoggingIn)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6C914)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Logging in...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _PrimaryButton(
                  label: 'LOG IN',
                  onPressed: _attemptLogin,
                ),
            ],
          ),
        );

      case SignInStep.email:
        return _AuthCard(
          key: const ValueKey('email'),
          title: 'Enter your Microsoft Email',
          onBack: () => _goToStep(SignInStep.login),
          child: Column(
            children: [
              _InputField(
                controller: _emailController,
                hintText: 'delacruzja@students.nu-lipa.edu.ph',
                prefix: const Icon(Icons.person, color: Color(0xFFF6C914)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: 'SEND CODE',
                onPressed: () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter your email')),
                    );
                    return;
                  }
                  final error = await AuthService.sendEmailCode(email);
                  if (error == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code sent. Check your email')),
                    );
                    _goToStep(SignInStep.code);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send code: $error')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      case SignInStep.code:
        return _AuthCard(
          key: const ValueKey('code'),
          title: 'Enter Code',
          subtitle: 'A 6-digit code was sent to your email. Please enter here.',
          onBack: () => _goToStep(SignInStep.email),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _CodeDigitField(
                    controller: _codeControllers[index],
                    focusNode: _codeFocusNodes[index],
                    nextFocusNode: index < 5 ? _codeFocusNodes[index + 1] : null,
                    previousFocusNode: index > 0 ? _codeFocusNodes[index - 1] : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter your email to resend the code')),
                    );
                    return;
                  }
                  final error = await AuthService.sendEmailCode(email);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error == null ? 'Code resent. Check your email.' : 'Failed to resend code: $error'),
                    ),
                  );
                },
                child: const Text(
                  'Resend Code',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 4),
              _PrimaryButton(
                label: 'VERIFY CODE',
                onPressed: () async {
                  final email = _emailController.text.trim();
                  final code = _codeControllers.map((c) => c.text).join();
                  if (code.length != 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter the 6-digit code')),
                    );
                    return;
                  }
                  final ok = await AuthService.verifyEmailCode(email, code);
                  if (ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Email verified')),
                    );
                    _goToStep(SignInStep.role);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invalid code')),
                    );
                  }
                },
              ),
            ],
          ),
        );

      case SignInStep.loginCode:
        return _AuthCard(
          key: const ValueKey('loginCode'),
          title: 'Verify Email',
          subtitle: 'Enter the 6-digit code sent to your email.',
          onBack: () => _goToStep(SignInStep.loginEmail),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _CodeDigitField(
                    controller: _codeControllers[index],
                    focusNode: _codeFocusNodes[index],
                    nextFocusNode: index < 5 ? _codeFocusNodes[index + 1] : null,
                    previousFocusNode: index > 0 ? _codeFocusNodes[index - 1] : null,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () {},
                child: const Text(
                  'Resend Code',
                  style: TextStyle(color: Colors.white70),
                ),
              ),

              const SizedBox(height: 10),

              _PrimaryButton(
                label: 'VERIFY',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const AppShell()),
                  );
                },
              ),
            ],
          ),
        );

      case SignInStep.role:
        return _AuthCard(
          key: const ValueKey('role'),
          title: 'Are you a?',
          onBack: () => _goToStep(SignInStep.code),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ChoiceChipButton(
                      label: 'Student',
                      selected: _selectedRole == 'Student',
                      onTap: () => setState(() => _selectedRole = 'Student'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ChoiceChipButton(
                      label: 'Faculty',
                      selected: _selectedRole == 'Faculty',
                      onTap: () => setState(() => _selectedRole = 'Faculty'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: 'PROCEED',
                onPressed: () => _goToStep(SignInStep.profile),
              ),
            ],
          ),
        );
      case SignInStep.profile:
        return _AuthCard(
          key: const ValueKey('profile'),
          title: 'Complete Profile',
          onBack: () => _goToStep(SignInStep.role),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'First Name',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _firstNameController,
                hintText: 'Juan',
                prefix: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFFF6C914),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last Name',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _lastNameController,
                hintText: 'Dela Cruz',
                prefix: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFFF6C914),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contact Number',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _contactNumberController,
                hintText: '09XXXXXXXXX',
                prefix: const Icon(Icons.phone, color: Color(0xFFF6C914)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Department',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _selectedDepartment,
                isExpanded: true,
                iconSize: 22,
                dropdownColor: const Color(0xFFF8F8FA),
                style: const TextStyle(color: Color(0xFF24304C)),
                decoration: _fieldDecoration(
                  hintText: 'Select your department',
                  prefix: const Icon(Icons.apartment, color: Color(0xFFF6C914)),
                ),
                items: _buildProgramDropdownItems(),
                onChanged: (value) {
                  if (value != null) {
                    final selected = _programOptions.firstWhere((option) => option.label == value);
                    setState(() {
                      _selectedDepartment = value;
                      _selectedProgramId = selected.id;
                    });
                  }
                },
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                label: 'PROCEED',
                onPressed: () => _goToStep(SignInStep.setPassword),
              ),
            ],
          ),
        );
      case SignInStep.setPassword:
        return _AuthCard(
          key: const ValueKey('setPassword'),
          title: 'Set Password',
          onBack: () => _goToStep(SignInStep.profile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Password',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _passwordController,
                hintText: '••••••••••••',
                prefix: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFF6C914),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Confirm Password',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _confirmPasswordController,
                hintText: '••••••••••••',
                prefix: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFF6C914),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              const Text(
                'Password Requirements',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ At least 8 characters',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '✓ At least 1 uppercase letter',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '✓ At least 1 lowercase letter',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '✓ At least 1 number',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  Text(
                    '✓ At least 1 special character',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (_isSavingAccount)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF6C914)),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Saving account...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _PrimaryButton(
                  label: 'SAVE',
                  onPressed: _attemptSignUp,
                ),
            ],
          ),
        );
    }
  }
}

class _ProgramOption {
  const _ProgramOption({required this.id, required this.label});

  final int id;
  final String label;
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    super.key,
    this.title,
    this.subtitle,
    this.onBack,
    required this.child,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF6B748F).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Back',
              ),
            ),
          if (title != null) ...[
            Text(
              title!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w300,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ],
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}

class _MicrosoftButton extends StatelessWidget {
  const _MicrosoftButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF141414),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _MicrosoftMark(size: 20),
                    const SizedBox(width: 14),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF141414),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _MicrosoftMark extends StatelessWidget {
  const _MicrosoftMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          _ColorSquare(Color(0xFFF25022)),
          _ColorSquare(Color(0xFF7FBA00)),
          _ColorSquare(Color(0xFF00A4EF)),
          _ColorSquare(Color(0xFFFFB900)),
        ],
      ),
    );
  }
}

class _ColorSquare extends StatelessWidget {
  const _ColorSquare(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: 9, height: 9, color: color);
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.hintText,
    this.prefix,
    this.keyboardType,
    this.controller,
    this.obscureText = false,
  });

  final String hintText;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final TextEditingController? controller;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Color(0xFF24304C)),
      decoration: _fieldDecoration(hintText: hintText, prefix: prefix),
    );
  }
}

class _CodeDigitField extends StatelessWidget {
  const _CodeDigitField({
    required this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.previousFocusNode,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final FocusNode? previousFocusNode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (value.length > 1) {
              controller.text = value.substring(value.length - 1);
              controller.selection = TextSelection.fromPosition(
                const TextPosition(offset: 1),
              );
            }
            if (nextFocusNode != null) {
              FocusScope.of(context).requestFocus(nextFocusNode);
            }
          } else if (previousFocusNode != null) {
            FocusScope.of(context).requestFocus(previousFocusNode);
          }
        },
        onSubmitted: (_) {
          if (nextFocusNode != null) {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
        },
        style: const TextStyle(color: Color(0xFF24304C), fontSize: 18),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFF6C914), width: 1.2),
          ),
        ),
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected
              ? const Color(0xFF32418C)
              : Colors.white.withValues(alpha: 0.92),
          foregroundColor: selected ? Colors.white : const Color(0xFF24304C),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _UploadBox extends StatelessWidget {
  const _UploadBox({required this.onTap, this.selectedImage});

  final VoidCallback onTap;
  final File? selectedImage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
        child: selectedImage != null
            ? Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      selectedImage!,
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Tap to change image',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB5B5B5),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              )
            : Column(
                children: const [
                  Icon(
                    Icons.upload_rounded,
                    color: Color(0xFFF6C914),
                    size: 30,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Upload a JPG or PNG file (up to 5MB)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFB5B5B5),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF6C914),
          foregroundColor: const Color(0xFF1A2254),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

InputDecoration _fieldDecoration({required String hintText, Widget? prefix}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFFB9B9B9),
      fontStyle: FontStyle.italic,
    ),
    prefixIcon: prefix == null
        ? null
        : Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: prefix,
          ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFFF6C914), width: 1.2),
    ),
  );
}
