import 'package:flutter/material.dart';

import 'calendar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 92,
              decoration: const BoxDecoration(
                color: Color(0xFF35489A),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF2C94C), width: 4),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'NUtilize',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Stack(
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
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE53935),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
                    Container(
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
                              onPressed: () {},
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
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CalendarPage(),
                                ),
                              );
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
                        const Expanded(
                          child: _ActionTile(
                            icon: Icons.description_outlined,
                            iconColor: Color(0xFF5A9E33),
                            label: 'Book Room',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFF35489A),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const _BottomNavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    selected: true,
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CalendarPage()),
                      );
                    },
                    child: const _BottomNavItem(
                      icon: Icons.calendar_month_outlined,
                      label: 'Calendar',
                    ),
                  ),
                  const _BottomNavItem(
                    icon: Icons.post_add_outlined,
                    label: 'Request',
                  ),
                  const _BottomNavItem(
                    icon: Icons.person_outline_rounded,
                    label: 'User',
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
      height: 88,
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
            decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1C1F2A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? Colors.white : Colors.white70;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
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
