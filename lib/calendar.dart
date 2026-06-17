import 'package:flutter/material.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

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
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: const [
                                  Text(
                                    'June 2022',
                                    style: TextStyle(
                                      color: Color(0xFF111111),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF35489A),
                                  ),
                                ],
                              ),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    color: Color(0xFF35489A),
                                    size: 30,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF35489A),
                                    size: 30,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              _WeekLabel('SUN'),
                              _WeekLabel('MON'),
                              _WeekLabel('TUE'),
                              _WeekLabel('WED'),
                              _WeekLabel('THU'),
                              _WeekLabel('FRI'),
                              _WeekLabel('SAT'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _CalendarGrid(
                            weeks: [
                              ['', '', '', '1', '2', '3', '4'],
                              ['5', '6', '7', '8', '9', '10', '11'],
                              ['12', '13', '14', '15', '16', '17', '18'],
                              ['19', '20', '21', '22', '23', '24', '25'],
                              ['26', '27', '28', '29', '30', '31', ''],
                            ],
                            selectedDay: '6',
                          ),
                        ],
                      ),
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _BottomNavItem(icon: Icons.home_rounded, label: 'Home'),
                  _BottomNavItem(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendar',
                    selected: true,
                  ),
                  _BottomNavItem(
                    icon: Icons.post_add_outlined,
                    label: 'Request',
                  ),
                  _BottomNavItem(
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

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFD0D0D6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({required this.weeks, required this.selectedDay});

  final List<List<String>> weeks;
  final String selectedDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: weeks
          .map(
            (week) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: week
                    .map(
                      (day) => _DayCell(day: day, selected: day == selectedDay),
                    )
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day, required this.selected});

  final String day;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    if (day.isEmpty) {
      return const SizedBox(width: 32, height: 32);
    }

    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF35489A) : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Text(
        day,
        style: TextStyle(
          color: selected ? Colors.white : const Color(0xFF111111),
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
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
