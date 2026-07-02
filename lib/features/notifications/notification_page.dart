import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_details_page.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  void initState() {
    super.initState();
    NotificationActivityStore.ensureSeeded(DateTime.now());
  }

  Future<void> _refresh() async {
    NotificationActivityStore.syncFromReservations(DateTime.now());
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }

  void _markAllAsRead() {
    NotificationActivityStore.markAllAsRead();
  }

  void _openNotification(NotificationRecord notification) {
    NotificationActivityStore.markAsRead(notification.id);

    switch (notification.targetKind) {
      case NotificationTargetKind.reservation:
        final reservation = notification.reservation;
        if (reservation != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReservationDetailsPage(reservation: reservation),
            ),
          );
        }
        break;
      case NotificationTargetKind.announcement:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnnouncementDetailsPage(
              title: notification.detailTitle ?? notification.title,
              body: notification.detailBody ?? notification.description,
            ),
          ),
        );
        break;
      case NotificationTargetKind.room:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoomDetailsPage(
              roomName: notification.roomName ?? 'Room Details',
              body: notification.roomDetails ?? notification.description,
            ),
          ),
        );
        break;
      case NotificationTargetKind.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Notifications'),
            Expanded(
              child: AnimatedBuilder(
                animation: NotificationActivityStore.listenable,
                builder: (context, _) {
                  final notifications = List<NotificationRecord>.from(
                    NotificationActivityStore.notifications,
                  )..sort((a, b) => b.date.compareTo(a.date));

                  return RefreshIndicator(
                    color: const Color(0xFF35489A),
                    onRefresh: _refresh,
                    child: notifications.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                            children: [
                              const SizedBox(height: 24),
                              _EmptyNotificationsState(onRefresh: _refresh),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _markAllAsRead,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF35489A),
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Mark All as Read',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              ..._buildGroups(notifications),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroups(List<NotificationRecord> notifications) {
    final now = DateTime.now();
    final today = <NotificationRecord>[];
    final yesterday = <NotificationRecord>[];
    final earlier = <NotificationRecord>[];

    for (final notification in notifications) {
      if (DateUtils.isSameDay(notification.date, now)) {
        today.add(notification);
      } else if (DateUtils.isSameDay(
        notification.date,
        now.subtract(const Duration(days: 1)),
      )) {
        yesterday.add(notification);
      } else {
        earlier.add(notification);
      }
    }

    final widgets = <Widget>[];
    if (today.isNotEmpty) {
      widgets.add(
        _NotificationGroup(
          title: 'Today',
          items: today,
          onTap: _openNotification,
        ),
      );
    }
    if (yesterday.isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
      }
      widgets.add(
        _NotificationGroup(
          title: 'Yesterday',
          items: yesterday,
          onTap: _openNotification,
        ),
      );
    }
    if (earlier.isNotEmpty) {
      if (widgets.isNotEmpty) {
        widgets.add(const SizedBox(height: 16));
      }
      widgets.add(
        _NotificationGroup(
          title: 'Earlier',
          items: earlier,
          onTap: _openNotification,
        ),
      );
    }
    return widgets;
  }
}

class _NotificationGroup extends StatelessWidget {
  const _NotificationGroup({
    required this.title,
    required this.items,
    required this.onTap,
  });

  final String title;
  final List<NotificationRecord> items;
  final ValueChanged<NotificationRecord> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4053A7),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        ...items.asMap().entries.map(
          (entry) => Padding(
            padding: EdgeInsets.only(
              bottom: entry.key == items.length - 1 ? 0 : 10,
            ),
            child: Dismissible(
              key: ValueKey(entry.value.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFD22828).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD22828),
                ),
              ),
              onDismissed: (_) {
                NotificationActivityStore.removeById(entry.value.id);
              },
              child: _NotificationCard(
                notification: entry.value,
                onTap: () => onTap(entry.value),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final NotificationRecord notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = notification.accentColor;
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(notification.icon, color: accent, size: 24),
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
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notification.relativeTimestamp(DateTime.now()),
                          style: const TextStyle(
                            color: Color(0xFF6A6F86),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
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
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (isUnread)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                    )
                  else
                    const SizedBox(height: 10),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF8A90A8),
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
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
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE4E7FB),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF35489A),
              size: 38,
            ),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 10),
          const Text(
            'Pull down to refresh when you want to check for updates.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6A6F86),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 150,
            child: ElevatedButton(
              onPressed: () => onRefresh(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35489A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Refresh',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementDetailsPage extends StatelessWidget {
  const AnnouncementDetailsPage({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Announcement Details'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.campaign_rounded,
                              color: Color(0xFFE94545),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Announcement',
                              style: TextStyle(
                                color: Color(0xFFE94545),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          style: const TextStyle(
                            color: Color(0xFF6A6F86),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomDetailsPage extends StatelessWidget {
  const RoomDetailsPage({
    super.key,
    required this.roomName,
    required this.body,
  });

  final String roomName;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Room Details'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Room Maintenance',
                          style: TextStyle(
                            color: Color(0xFF35489A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          roomName,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          body,
                          style: const TextStyle(
                            color: Color(0xFF6A6F86),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
