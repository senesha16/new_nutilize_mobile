import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_nutilize_mobile/features/auth/sign_in_flow.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/request.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';
import 'package:new_nutilize_mobile/features/request/reservation_history_page.dart';
import 'package:new_nutilize_mobile/features/user/request_history_page.dart';
import 'package:new_nutilize_mobile/features/user/user_guide_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.showBottomNavigation = true});

  final bool showBottomNavigation;

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final userName = user?['username'] ?? 'Unknown';
    final email = user?['email'] ?? 'No email';
    final role = user?['role'] ?? 'No role';
    final department = user?['affiliation']?.toString() ?? 'No department';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const AppHeader(title: 'NUtilize'),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4E9FA),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF35489A),
                                    size: 34,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        userName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF111111),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        role,
                                        style: const TextStyle(
                                          color: Color(0xFF35489A),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        email,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF8A90A8),
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        department,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF8A90A8),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Main Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 28, 22, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ActivityCard(
                                icon: Icons.menu_book_rounded,
                                title: 'Need help?',
                                subtitle: 'Open the step-by-step user guide',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const UserGuidePage(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Reservation Stats
                              _ReservationStats(),
                              const SizedBox(height: 28),
                              // Activity Section
                              _SectionTitle(title: 'Activity'),
                              const SizedBox(height: 12),
                              _ActivityCard(
                                icon: Icons.history_rounded,
                                title: 'Reservation History',
                                subtitle:
                                    'View your room and item reservations',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ReservationHistoryPage(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _ActivityCard(
                                icon: Icons.receipt_long_rounded,
                                title: 'Request History',
                                subtitle: 'Review your submitted requests',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RequestHistoryPage(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                              // Logout Button
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _handleDeleteAccount(context),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  label: const Text('Delete Account'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFE53935),
                                    side: const BorderSide(
                                      color: Color(0xFFE53935),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await AuthService.signOut();
                                    if (context.mounted) {
                                      Navigator.of(context).pushAndRemoveUntil(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SignInFlowPage(),
                                        ),
                                        (route) => false,
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.logout_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Logout'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE53935),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: showBottomNavigation
          ? AppBottomNav(
              selectedIndex: AppShellScope.maybeOf(context)?.currentIndex ?? 3,
              onTap: (index) {
                final shell = AppShellScope.maybeOf(context);
                if (shell != null) {
                  shell.onTabSelected(index);
                  return;
                }
                final pages = [
                  const HomePage(),
                  const CalendarPage(),
                  const RequestPage(),
                  const ProfilePage(),
                ];
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => pages[index]),
                );
              },
            )
          : null,
    );
  }
}

Future<void> _handleDeleteAccount(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: Color(0xFFE53935),
        size: 36,
      ),
      title: const Text(
        'Delete your account?',
        style: TextStyle(color: Color(0xFF111111), fontWeight: FontWeight.w800),
      ),
      content: const Text(
        'This permanently removes your profile, reservations, reports, and uploaded files. You’ll need to verify your email before deletion.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF626A80), height: 1.45),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF35489A),
                  side: const BorderSide(color: Color(0xFFD8DDF0)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Keep account'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final email = AuthService.currentUser?['email']?.toString() ?? '';
  final sendError = await _withAccountDeletionProgress(
    context,
    'Sending your verification code…',
    () => AuthService.sendAccountDeletionCode(email),
  );
  if (!context.mounted) return;
  if (sendError != null) {
    await _showAccountDeletionError(context, sendError);
    return;
  }

  final codeController = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(
          Icons.mark_email_read_outlined,
          color: Color(0xFF35489A),
          size: 34,
        ),
        title: const Text(
          'Verify it’s you',
          style: TextStyle(
            color: Color(0xFF111111),
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the 6-digit code sent to ${_maskEmail(email)} to confirm account deletion.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF626A80), height: 1.45),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              onChanged: (_) => setDialogState(() {}),
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                filled: true,
                fillColor: const Color(0xFFF3F5FB),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD8DDF0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD8DDF0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFF35489A),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF35489A),
                    side: const BorderSide(color: Color(0xFFD8DDF0)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: codeController.text.length == 6
                      ? () =>
                            Navigator.of(dialogContext).pop(codeController.text)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF35489A),
                    disabledBackgroundColor: const Color(0xFFD8DDF0),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Verify'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  codeController.dispose();
  if (code == null || code.trim().isEmpty || !context.mounted) return;

  final deleted = await _withAccountDeletionProgress(
    context,
    'Securely deleting your account…',
    () => AuthService.deleteAccount(code: code),
  );
  if (!context.mounted) return;
  if (!deleted) {
    await _showAccountDeletionError(
      context,
      'The code is invalid or the account could not be deleted. Your account is still active.',
    );
    return;
  }

  await Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const AccountDeletedPage()),
  );
}

Future<T> _withAccountDeletionProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() operation,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF35489A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF252A3A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await operation();
  } finally {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

String _maskEmail(String email) {
  final parts = email.split('@');
  if (parts.length != 2 || parts.first.isEmpty) return 'your email address';
  final name = parts.first;
  final visiblePrefix = name.length == 1 ? name : name.substring(0, 2);
  return '$visiblePrefix•••@${parts.last}';
}

Future<void> _showAccountDeletionError(BuildContext context, String message) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Account not deleted'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

class AccountDeletedPage extends StatelessWidget {
  const AccountDeletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 34, 28, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 24,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5ED),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF2E9D50),
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const Text(
                      'Account deleted',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your NUtilize Mobile account and associated data have been removed.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF626A80),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5FB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Thank you for being part of NUtilize. We’re sorry to see you go, and you’re always welcome back.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF35489A),
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          await AuthService.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const SignInFlowPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF35489A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Return to sign in',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReservationStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ReservationActivityStore.listenable,
      builder: (context, _) {
        final allReservations = collectReservations(DateTime.now());
        final active = allReservations
            .where((r) => !_isCompletedStatus(r.reservationStatus))
            .length;
        final completed = allReservations
            .where((r) => _isCompletedStatus(r.reservationStatus))
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: 'Your Reservations'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    number: active,
                    label: 'Active Reservations',
                    color: const Color(0xFF35489A),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatCard(
                    number: completed,
                    label: 'Completed Requests',
                    color: const Color(0xFFF6C914),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

bool _isCompletedStatus(String status) {
  final normalized = status.toLowerCase();
  return normalized.contains('completed') ||
      normalized.contains('returned') ||
      normalized.contains('cancelled') ||
      normalized.contains('rejected') ||
      normalized.contains('denied');
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5FB),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF35489A)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8A90A8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF7A8199)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int number;
  final String label;
  final Color color;

  const _StatCard({
    required this.number,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E7FB), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            number.toString(),
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8A90A8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF111111),
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E7FB), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8A90A8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6C914).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFFF6C914),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
