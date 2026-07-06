import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/auth/sign_in_flow.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_page.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.onNotificationTap,
    this.showNotificationDot = true,
  });

  final String title;
  final VoidCallback? onNotificationTap;
  final bool showNotificationDot;

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.currentUser?['username'] ?? 'User';
    
    return Container(
      width: double.infinity,
      height: 92,
      decoration: const BoxDecoration(
        color: Color(0xFF35489A),
        border: Border(bottom: BorderSide(color: Color(0xFFF2C94C), width: 4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/nutilize_logo.png',
            height: 38,
            fit: BoxFit.contain,
          ),
          Row(
            children: [
              GestureDetector(
                onTap:
                    onNotificationTap ??
                    () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationPage()),
                      );
                    },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        color: Color(0xFF35489A),
                        size: 25,
                      ),
                    ),
                    if (showNotificationDot)
                      const Positioned(
                        right: 2,
                        top: 2,
                        child: CircleAvatar(
                          radius: 5,
                          backgroundColor: Color(0xFFE53935),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<String>(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF35489A),
                    size: 22,
                  ),
                ),
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logged in as:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem<String>(
                    onTap: () async {
                      await AuthService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const SignInFlowPage()),
                          (route) => false,
                        );
                      }
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 18, color: Color(0xFFE53935)),
                        SizedBox(width: 8),
                        Text(
                          'Logout',
                          style: TextStyle(color: Color(0xFFE53935)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
