import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, String>? _recentActivity;

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Good Evening, Juan! 👋',
                      style: TextStyle(
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
                    _AnnouncementCard(
                      title: 'Engr. Abante',
                      time: 'Yesterday • 6:07 PM',
                      headline: 'Room 618 Scheduled Maintenance',
                      body:
                          'Please be advised that Room 618 will undergo scheduled maintenance on June 15, 2026, from 8:00 AM to 5:00 PM. The room will be temporarily unavailable for reservations during this period. Thank you for your understanding.',
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Dot(active: false),
                          SizedBox(width: 6),
                          _Dot(active: true),
                          SizedBox(width: 6),
                          _Dot(active: false),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Recent Activity',
                      style: TextStyle(
                        color: Color(0xFF4053A7),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _recentActivity == null
                        ? Container(
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
                                  height: 22,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      AppShellScope.maybeOf(
                                        context,
                                      )?.onTabSelected(2);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF35489A),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    child: const Text(
                                      '+ Make a Reservation',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildRecentActivityCard(),
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
                          child: GestureDetector(
                            onTap: () {
                              AppShellScope.maybeOf(context)?.onTabSelected(1);
                            },
                            child: const _ActionTile(
                              icon: Icons.event_note_rounded,
                              iconColor: Color(0xFFF6C914),
                              label: 'View Calendar',
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: _ActionTile(
                            icon: Icons.history_rounded,
                            iconColor: Color(0xFF5DA1FF),
                            label: 'View History',
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              AppShellScope.maybeOf(context)?.onTabSelected(2);
                            },
                            child: const _ActionTile(
                              icon: Icons.description_outlined,
                              iconColor: Color(0xFF5A9E33),
                              label: 'Book Venue',
                            ),
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

  Widget _buildRecentActivityCard() {
    final activity = _recentActivity!;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF35489A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['room'] ?? 'Room Reservation',
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activity['subtitle'] ?? 'Room Reservation',
                      style: const TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE4A7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activity['status'] ?? 'Pending Approval',
                  style: const TextStyle(
                    color: Color(0xFF4D3E00),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: Color(0xFF6A6F86),
              ),
              const SizedBox(width: 8),
              Text(
                activity['date'] ?? '',
                style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
              ),
              const SizedBox(width: 18),
              const Icon(
                Icons.access_time_rounded,
                size: 16,
                color: Color(0xFF6A6F86),
              ),
              const SizedBox(width: 8),
              Text(
                activity['time'] ?? '',
                style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF1C1F2A),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
