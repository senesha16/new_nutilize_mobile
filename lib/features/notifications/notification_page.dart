import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_details_page.dart';
import 'package:new_nutilize_mobile/features/notifications/announcement_details_page.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_data.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';

Route<T> _fadePageRoute<T>(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            _NotificationHeader(
              onBack: () => Navigator.of(context).pop(),
              onMarkAllRead: NotificationCenterStore.markAllAsRead,
            ),
            Expanded(
              child: ValueListenableBuilder<List<NotificationItem>>(
                valueListenable: NotificationCenterStore.listenable,
                builder: (context, notifications, child) {
                  if (notifications.isEmpty) {
                    return RefreshIndicator(
                      color: const Color(0xFF35489A),
                      onRefresh: NotificationCenterStore.refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                        children: [
                          const SizedBox(height: 28),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x14000000),
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6EAF9),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: const Icon(
                                    Icons.notifications_none_rounded,
                                    color: Color(0xFF35489A),
                                    size: 46,
                                  ),
                                ),
                                const SizedBox(height: 22),
                                const Text(
                                  "You're all caught up! New notifications will appear here.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF111111),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final grouped = <String, List<NotificationItem>>{};
                  for (final notification in notifications) {
                    grouped
                        .putIfAbsent(
                          notification.groupLabel,
                          () => <NotificationItem>[],
                        )
                        .add(notification);
                  }

                  const order = ['Today', 'Yesterday', 'Earlier'];
                  return RefreshIndicator(
                    color: const Color(0xFF35489A),
                    onRefresh: NotificationCenterStore.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                      children: [
                        for (final group in order)
                          if (grouped[group] != null &&
                              grouped[group]!.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                group,
                                style: const TextStyle(
                                  color: Color(0xFF4053A7),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ...grouped[group]!.map(
                              (notification) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Dismissible(
                                  key: ValueKey(notification.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onDismissed: (_) =>
                                      NotificationCenterStore.delete(
                                        notification.id,
                                      ),
                                  child: _NotificationTile(
                                    notification: notification,
                                    onTap: () {
                                      NotificationCenterStore.markAsRead(
                                        notification.id,
                                      );
                                      _openNotification(context, notification);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                      ],
                    ),
                  );
                },
              ),
            ),
            AppBottomNav(
              selectedIndex: 0,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openNotification(BuildContext context, NotificationItem notification) {
    if (notification.category == NotificationCategory.reservationSubmitted ||
        notification.category == NotificationCategory.reservationApproved ||
        notification.category == NotificationCategory.reservationRejected ||
        notification.category == NotificationCategory.reservationCancelled ||
        notification.category == NotificationCategory.reservationReminder) {
      final reservation = notification.reservation;
      if (reservation != null) {
        Navigator.of(context).push(
          _fadePageRoute(ReservationDetailsPage(reservation: reservation)),
        );
      }
      return;
    }

    Navigator.of(context).push(
      _fadePageRoute(
        AnnouncementDetailsPage(
          title: notification.detailTitle ?? notification.title,
          body: notification.detailBody ?? notification.description,
          dateLabel:
              notification.detailDateLabel ?? notification.relativeTimestamp,
          leadingIcon: notification.icon,
          leadingColor: notification.accentColor,
        ),
      ),
    );
  }
}

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({
    required this.onBack,
    required this.onMarkAllRead,
  });

  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      color: const Color(0xFF35489A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const Text(
            'Notifications',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Positioned(
            right: 12,
            child: TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Mark All',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationItem notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: notification.isRead
                  ? Colors.transparent
                  : const Color(0xFFE6EAF9),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: notification.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: const Color(0xFF111111),
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.description,
                      style: const TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notification.relativeTimestamp,
                      style: const TextStyle(
                        color: Color(0xFF8A8FA3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6A6F86),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
