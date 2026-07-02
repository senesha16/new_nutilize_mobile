import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_page.dart';

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
        ],
      ),
    );
  }
}
