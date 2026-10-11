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

  // Forgot password
  forgotPasswordEmail,
  forgotPasswordCode,
  forgotPasswordPassword,
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
    _ProgramOption(
      id: 6,
      label:
          'BS Information Technology with specialization in Mobile and Web Applications',
    ),
    _ProgramOption(id: 7, label: 'BS Accountancy'),
    _ProgramOption(id: 8, label: 'BSBA Major in Financial Management'),
    _ProgramOption(id: 9, label: 'BSBA Major in Marketing Management'),
    _ProgramOption(id: 10, label: 'BS Management Accounting'),
    _ProgramOption(id: 11, label: 'BS Tourism Management'),
    _ProgramOption(id: 12, label: 'BS Psychology'),
    _ProgramOption(id: 13, label: 'BS Medical Technology'),
    _ProgramOption(id: 14, label: 'BS Nursing'),
  ];

  bool canProceedFromProfilePage({String? selectedDepartment}) {
    final department = (selectedDepartment ?? _selectedDepartment)?.trim();
    return department != null && department.isNotEmpty;
  }

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
  final TextEditingController _resetPasswordController =
      TextEditingController();
  final TextEditingController _resetConfirmPasswordController =
      TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final List<TextEditingController> _codeControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _codeFocusNodes = List.generate(6, (_) => FocusNode());

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
  bool _isSendingResetCode = false;
  bool _isVerifyingResetCode = false;
  bool _isSubmittingNewPassword = false;
  bool _isSendingRegistrationCode = false;
  bool _isResendingRegistrationCode = false;
  bool _isVerifyingRegistrationCode = false;

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
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      } else {
        final error =
            AuthService.lastAuthError ?? 'Login failed. Check credentials.';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: ${e.toString()}')));
    } finally {
      if (mounted && _step == SignInStep.loginEmail) {
        setState(() {
          _isLoggingIn = false;
        });
      }
    }
  }

  bool _isSavingAccount = false;
  bool _acceptedDataPrivacy = false;

  bool _isNuRegistrationEmail(String email) {
    final domain = email.trim().toLowerCase().split('@').last;
    return domain == 'students.nu-lipa.edu.ph' || domain == 'nu-lipa.edu.ph';
  }

  Future<void> _sendRegistrationCode({bool resend = false}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resend
                ? 'Enter your email to resend the code'
                : 'Please enter your email',
          ),
        ),
      );
      return;
    }
    if (!_isNuRegistrationEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('only NU email allowed')),
      );
      return;
    }
    if (_isSendingRegistrationCode || _isResendingRegistrationCode) return;

    for (final controller in _codeControllers) {
      controller.clear();
    }
    setState(() {
      if (resend) {
        _isResendingRegistrationCode = true;
      } else {
        _isSendingRegistrationCode = true;
      }
    });

    try {
      final error = await AuthService.sendEmailCode(email);
      if (!mounted) return;

      if (error == null) {
        if (resend) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code resent. Check your email.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code sent. Check your email')),
          );
          _goToStep(SignInStep.code);
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error == 'Email is already taken.' ||
                    error == 'only NU email allowed'
                ? error
                : 'Failed to send code: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSendingRegistrationCode = false;
          _isResendingRegistrationCode = false;
        });
      }
    }
  }

  Future<void> _verifyRegistrationCode() async {
    final email = _emailController.text.trim();
    final code = _codeControllers.map((controller) => controller.text).join();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }
    if (_isVerifyingRegistrationCode) return;

    setState(() => _isVerifyingRegistrationCode = true);
    try {
      final isValid = await AuthService.verifyEmailCode(email, code);
      if (!mounted) return;

      if (isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Email verified')));
        _goToStep(SignInStep.role);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invalid code')));
      }
    } finally {
      if (mounted) {
        setState(() => _isVerifyingRegistrationCode = false);
      }
    }
  }

  Future<void> _sendForgotPasswordCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }

    for (final controller in _codeControllers) {
      controller.clear();
    }

    setState(() {
      _isSendingResetCode = true;
    });

    try {
      final error = await AuthService.sendForgotPasswordCode(email);
      if (!mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset code sent. Check your email.')),
        );
        _goToStep(SignInStep.forgotPasswordCode);
        return;
      }

      if (error == 'No account found, register account first') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found, register account first'),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingResetCode = false;
        });
      }
    }
  }

  Future<void> _verifyForgotPasswordCode() async {
    final email = _emailController.text.trim();
    final code = _codeControllers.map((c) => c.text).join();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 6-digit code')),
      );
      return;
    }

    setState(() {
      _isVerifyingResetCode = true;
    });

    try {
      final ok = await AuthService.verifyForgotPasswordCode(email, code);
      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Code verified')));
        _goToStep(SignInStep.forgotPasswordPassword);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect code, try again')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingResetCode = false;
        });
      }
    }
  }

  Future<void> _submitNewPassword() async {
    final email = _emailController.text.trim();
    final password = _resetPasswordController.text;
    final confirm = _resetConfirmPasswordController.text;

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first')),
      );
      return;
    }

    if (password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter and confirm your new password'),
        ),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters long.'),
        ),
      );
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() {
      _isSubmittingNewPassword = true;
    });

    try {
      final ok = await AuthService.resetPassword(
        email: email,
        code: _codeControllers.map((controller) => controller.text).join(),
        newPassword: password,
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated successfully')),
        );
        _emailController.clear();
        _passwordController.clear();
        _resetPasswordController.clear();
        _resetConfirmPasswordController.clear();
        for (final controller in _codeControllers) {
          controller.clear();
        }
        _goToStep(SignInStep.login);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update password. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingNewPassword = false;
        });
      }
    }
  }

  void _showDataPrivacyNotice() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 28,
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF35489A),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Privacy Notice',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Republic Act No. 10173',
                        style: TextStyle(
                          color: Color(0xFFF6C914),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'We value your privacy and are committed to protecting your personal information. This notice explains how NUtilize collects, uses, and safeguards your data. By creating an account, you acknowledge that your information will be handled for the purposes described here, in line with the Data Privacy Act of 2012 (Republic Act No. 10173).',
                          style: TextStyle(
                            color: Color(0xFF2C3142),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'This notice applies to students and other NU Lipa users of NUtilize, the room and item reservation system. It describes what this app collects, why it is processed, how it is protected, who can see it, and your rights under RA 10173.',
                          style: TextStyle(
                            color: Color(0xFF2C3142),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 14),
                        _PrivacySection(
                          title: 'Personal Data We Collect',
                          body:
                              'When you register and use NUtilize, we collect your name, NU email address, contact number, role, and academic program. We also keep the password you set, the email verification used to create your account, and the reservation details you submit, including the room or item, date and time, purpose, and the approval or rejection history of that request.\n\nNUtilize does not collect grades, enrollment records, employment or payroll records, health information, or government ID numbers.',
                        ),
                        _PrivacySection(
                          title: 'Why We Process Your Personal Data',
                          body:
                              'Your information is used only for this reservation service: to create and secure your account, to confirm that registration uses an NU Lipa email, to receive and route requests to the offices assigned to approve them, to show you the status of those requests, and to keep rooms and items from being double-booked.',
                        ),
                        _PrivacySection(
                          title: 'How NUtilize Uses Your Data',
                          body:
                              'You enter your details on the registration and reservation screens. NUtilize uses them to create your account, limit what you can see after you sign in, process room and item requests, update their status, and notify you when a request is approved, rejected, or still waiting on an office.',
                        ),
                        _PrivacySection(
                          title: 'Sharing and Disclosure',
                          body:
                              'NUtilize does not sell your personal data. Your account details and reservation requests are available to you, and a request is shared with the offices assigned to review and approve it. It is not shared for marketing or for purposes outside this reservation service.',
                        ),
                        _PrivacySection(
                          title: 'Retention',
                          body:
                              'Account and reservation records are kept for as long as they are needed to operate NUtilize and to keep a record of requests and their results. These records are not official academic credentials, such as a transcript of records.',
                        ),
                        _PrivacySection(
                          title: 'Security Measures',
                          body:
                              'Access is limited to your account and to the offices assigned to a request. Your password is used only to sign in. Approval history stays with the reservation so the status of a request can be reviewed.',
                        ),
                        _PrivacySection(
                          title: 'Your Rights',
                          body:
                              'Under RA 10173, you have the right to be informed, to access your personal data, to object, to correct inaccurate information, to suspend or withdraw processing where the law allows, to request erasure or blocking, and to file a complaint with the National Privacy Commission. Checking the box means you have read and understood this notice.',
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF6C914),
                        foregroundColor: const Color(0xFF1A2254),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'CLOSE',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 8 characters long.'),
        ),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (!_acceptedDataPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please confirm that you have read and understood the Data Privacy Notice.',
          ),
        ),
      );
      return;
    }

    final affiliation = _selectedDepartment?.trim();
    if (affiliation == null || affiliation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your program before creating your account.',
          ),
        ),
      );
      return;
    }

    final programId =
        _selectedProgramId ?? AuthService.programIdForAffiliation(affiliation);
    if (programId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a valid program before creating your account.',
          ),
        ),
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

      final result = await AuthService.signUp(
        email: email,
        password: password,
        verificationCode: _codeControllers
            .map((controller) => controller.text)
            .join(),
        profile: profile,
      );
      final error = result['error'] as String?;

      if (error == null) {
        final warning = result['warning'] as String?;
        if (warning != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('✓ $warning')));
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Account created. Please log in to continue.'),
          ),
        );

        _goToStep(SignInStep.loginEmail);
        _emailController.text = email;
        _passwordController.clear();
        _confirmPasswordController.clear();
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Registration failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAccount = false;
        });
      }
    }
  }

  void _goToStep(SignInStep step) {
    if (step == SignInStep.email ||
        step == SignInStep.forgotPasswordEmail ||
        step == SignInStep.loginEmail) {
      for (final controller in _codeControllers) {
        controller.clear();
      }
    }
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

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _emailController.text = _emailController.text.trim();
                    _goToStep(SignInStep.forgotPasswordEmail);
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: Color(0xFFF6C914),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF6C914),
                          ),
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
                _PrimaryButton(label: 'LOG IN', onPressed: _attemptLogin),
            ],
          ),
        );

      case SignInStep.forgotPasswordEmail:
        return _AuthCard(
          key: const ValueKey('forgotPasswordEmail'),
          title: 'Forgot Password',
          subtitle: 'Enter your email to receive a reset code.',
          onBack: () => _goToStep(SignInStep.loginEmail),
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
              const SizedBox(height: 20),
              if (_isSendingResetCode)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF6C914),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Sending code...',
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
                  label: 'CONFIRM EMAIL',
                  onPressed: _sendForgotPasswordCode,
                ),
            ],
          ),
        );

      case SignInStep.forgotPasswordCode:
        return _AuthCard(
          key: const ValueKey('forgotPasswordCode'),
          title: 'Reset Code',
          subtitle: 'Enter the 6-digit code sent to your email.',
          onBack: () => _goToStep(SignInStep.forgotPasswordEmail),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => _CodeDigitField(
                    controller: _codeControllers[index],
                    focusNode: _codeFocusNodes[index],
                    nextFocusNode: index < 5
                        ? _codeFocusNodes[index + 1]
                        : null,
                    previousFocusNode: index > 0
                        ? _codeFocusNodes[index - 1]
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _sendForgotPasswordCode,
                child: const Text(
                  'Resend Code',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 10),
              if (_isVerifyingResetCode)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF6C914),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Verifying code...',
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
                  label: 'VERIFY RESET CODE',
                  onPressed: _verifyForgotPasswordCode,
                ),
            ],
          ),
        );

      case SignInStep.forgotPasswordPassword:
        return _AuthCard(
          key: const ValueKey('forgotPasswordPassword'),
          title: 'Enter New Password',
          subtitle: 'Create a new password for your account.',
          onBack: () => _goToStep(SignInStep.forgotPasswordCode),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter new password',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _resetPasswordController,
                hintText: '••••••••••••',
                obscureText: true,
                prefix: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFF6C914),
                ),
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Re Enter new password',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              const SizedBox(height: 6),
              _InputField(
                controller: _resetConfirmPasswordController,
                hintText: '••••••••••••',
                obscureText: true,
                prefix: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFFF6C914),
                ),
              ),
              const SizedBox(height: 18),
              if (_isSubmittingNewPassword)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF6C914),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Saving password...',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _PrimaryButton(label: 'SUBMIT', onPressed: _submitNewPassword),
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
                isLoading: _isSendingRegistrationCode,
                loadingLabel: 'SENDING CODE...',
                onPressed: () => _sendRegistrationCode(),
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
                    nextFocusNode: index < 5
                        ? _codeFocusNodes[index + 1]
                        : null,
                    previousFocusNode: index > 0
                        ? _codeFocusNodes[index - 1]
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _isResendingRegistrationCode
                    ? null
                    : () => _sendRegistrationCode(resend: true),
                child: _isResendingRegistrationCode
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFFF6C914),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Sending code...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      )
                    : const Text(
                        'Resend Code',
                        style: TextStyle(color: Colors.white70),
                      ),
              ),
              const SizedBox(height: 4),
              _PrimaryButton(
                label: 'VERIFY CODE',
                isLoading: _isVerifyingRegistrationCode,
                loadingLabel: 'VERIFYING...',
                onPressed: _verifyRegistrationCode,
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
                    nextFocusNode: index < 5
                        ? _codeFocusNodes[index + 1]
                        : null,
                    previousFocusNode: index > 0
                        ? _codeFocusNodes[index - 1]
                        : null,
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
                    final selected = _programOptions.firstWhere(
                      (option) => option.label == value,
                    );
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
                onPressed: () {
                  if (!canProceedFromProfilePage()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select your department before continuing.',
                        ),
                      ),
                    );
                    return;
                  }
                  _goToStep(SignInStep.setPassword);
                },
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
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _acceptedDataPrivacy,
                      onChanged: (value) {
                        setState(() {
                          _acceptedDataPrivacy = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFFF6C914),
                      checkColor: const Color(0xFF1A2254),
                      side: const BorderSide(color: Colors.white),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text.rich(
                        TextSpan(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.35,
                          ),
                          children: [
                            const TextSpan(
                              text: 'I have read and understood the ',
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: _showDataPrivacyNotice,
                                child: const Text(
                                  'Data Privacy Notice',
                                  style: TextStyle(
                                    color: Color(0xFF8EC5FF),
                                    fontSize: 12,
                                    height: 1.35,
                                    fontWeight: FontWeight.w700,
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFF8EC5FF),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFF6C914),
                          ),
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
                _PrimaryButton(label: 'SAVE', onPressed: _attemptSignUp),
            ],
          ),
        );
    }
  }
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF35489A),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF2C3142),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
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
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
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

class _InputField extends StatefulWidget {
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
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      obscureText: _isObscured,
      style: const TextStyle(color: Color(0xFF24304C)),
      decoration:
          _fieldDecoration(
            hintText: widget.hintText,
            prefix: widget.prefix,
          ).copyWith(
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _isObscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                      color: const Color(0xFF24304C),
                    ),
                    onPressed: () {
                      setState(() {
                        _isObscured = !_isObscured;
                      });
                    },
                  )
                : null,
          ),
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
        textInputAction: nextFocusNode != null
            ? TextInputAction.next
            : TextInputAction.done,
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
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.loadingLabel,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF6C914),
          foregroundColor: const Color(0xFF1A2254),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1A2254),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    loadingLabel ?? label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
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
