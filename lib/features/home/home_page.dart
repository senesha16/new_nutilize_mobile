import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_details_page.dart';
import 'package:new_nutilize_mobile/features/request/reservation_history_page.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userName = AuthService.currentUser?['username'] ?? 'User';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'NUtilize'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Evening, $userName! 👋',
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Announcements',
                      style: TextStyle(
                        color: Color(0xFFE31E24),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _AnnouncementCard(
                      title: 'Engr. Abante',
                      time: 'Yesterday • 6:07 PM',
                      headline: 'Room 618 Scheduled Maintenance',
                      body:
                          'Please be advised that Room 618 will undergo scheduled maintenance on June 15, 2026, from 8:00 AM to 5:00 PM. The room will be temporarily unavailable for reservations during this period. Thank you for your understanding.',
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Dot(active: false),
                        SizedBox(width: 6),
                        _Dot(active: true),
                        SizedBox(width: 6),
                        _Dot(active: false),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recent Activity',
                          style: TextStyle(
                            color: Color(0xFF4053A7),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReservationHistoryPage(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF35489A),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: ReservationActivityStore.listenable,
                      builder: (context, child) {
                        final recentActivities = recentReservations(
                          DateTime.now(),
                        );
                        if (recentActivities.isEmpty) {
                          return _EmptyActivityCard(
                            onReserve: () {
                              AppShellScope.maybeOf(context)?.onTabSelected(2);
                            },
                          );
                        }

                        return Column(
                          children: recentActivities
                              .map(
                                (reservation) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _RecentActivityCard(
                                    reservation: reservation,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReservationDetailsPage(
                                                reservation: reservation,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: Color(0xFF4053A7),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.event_note_rounded,
                            iconColor: const Color(0xFFF6C914),
                            label: 'View Calendar',
                            onTap: () {
                              AppShellScope.maybeOf(context)?.onTabSelected(1);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.history_rounded,
                            iconColor: const Color(0xFF5DA1FF),
                            label: 'View History',
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const ReservationHistoryPage(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _ActionTile(
                            icon: Icons.description_outlined,
                            iconColor: const Color(0xFF5A9E33),
                            label: 'Book Venue',
                            onTap: () {
                              AppShellScope.maybeOf(context)?.onTabSelected(2);
                            },
                          ),
                        ),
                      ],
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

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard({required this.onReserve});

  final VoidCallback onReserve;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFE6EAF9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'No Recent Activity yet.',
            style: TextStyle(
              color: Color(0xFF464D6A),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 185,
            height: 28,
            child: ElevatedButton(
              onPressed: onReserve,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF35489A),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                '+ Make a Reservation',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.reservation, required this.onTap});

  final ReservationRecord reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (reservation.reservationStatus.toLowerCase()) {
      'approved' || 'completed' => const Color(0xFF2E9D50),
      'cancelled' => const Color(0xFFD22828),
      'rejected' => const Color(0xFFD22828),
      _ => const Color(0xFFD79700),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE4E7FB),
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6EAF9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.meeting_room_outlined,
                      color: Color(0xFF35489A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reservation.roomName,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reservation.reservationType,
                          style: const TextStyle(
                            color: Color(0xFF6A6F86),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    label: reservation.reservationStatus,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF1C1F2A),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Color(0xFF6A6F86),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _formatDate(reservation.date),
                    style: const TextStyle(
                      color: Color(0xFF6A6F86),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: Color(0xFF6A6F86),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      reservation.reservationTime,
                      style: const TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 11,
                      ),
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({
    required this.title,
    required this.time,
    required this.headline,
    required this.body,
  });

  final String title;
  final String time;
  final String headline;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E7FB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFC9CCD6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFE94545),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF60667B),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 100,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FB),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1C1F2A),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4053A7) : const Color(0xFFAEB4C8),
        shape: BoxShape.circle,
      ),
    );
  }
}
