import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/user/report_issue_page.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class UserGuidePage extends StatelessWidget {
  const UserGuidePage({super.key});

  static const _steps = <_GuideStepData>[
    _GuideStepData(
      number: '01',
      icon: Icons.explore_outlined,
      title: 'Explore the app',
      description:
          'Use the bottom menu to move between Home, Calendar, Request, and User.',
    ),
    _GuideStepData(
      number: '02',
      icon: Icons.widgets_outlined,
      title: 'Choose what you need',
      description:
          'Open Request and select Venue Reservation for spaces, or Item Reservation for equipment.',
    ),
    _GuideStepData(
      number: '03',
      icon: Icons.edit_calendar_outlined,
      title: 'Submit your request',
      description:
          'Choose an available resource and schedule, complete the required details, then review and submit your request.',
    ),
    _GuideStepData(
      number: '04',
      icon: Icons.track_changes_rounded,
      title: 'Follow its progress',
      description:
          'Open Request History to review your submitted requests and their status. Requests may pass through multiple approval offices.',
    ),
    _GuideStepData(
      number: '05',
      icon: Icons.calendar_month_outlined,
      title: 'Check your schedule',
      description:
          'Use Calendar to view your reservations, and Home to review recent reservation activity.',
    ),
    _GuideStepData(
      number: '06',
      icon: Icons.assignment_turned_in_outlined,
      title: 'Complete the reservation',
      description:
          'Follow the approved schedule and return borrowed items as arranged. An overdue reservation may prevent new requests until it is resolved.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'User Guide'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
                children: [
                  const _GuideIntroCard(),
                  const SizedBox(height: 22),
                  const Text(
                    'HOW TO USE NUTILIZE',
                    style: TextStyle(
                      color: Color(0xFF35489A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var index = 0; index < _steps.length; index++) ...[
                    _GuideStepCard(
                      step: _steps[index],
                      isLast: index == _steps.length - 1,
                    ),
                    if (index != _steps.length - 1) const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  const _SupportCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideIntroCard extends StatelessWidget {
  const _GuideIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF35489A), Color(0xFF263779)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2635489A),
            blurRadius: 18,
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
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Color(0xFFF6C914),
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your NUtilize guide',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'A quick walkthrough for finding campus resources, making requests, and keeping track of reservations.',
                  style: TextStyle(
                    color: Color(0xFFE4E9FF),
                    fontSize: 13,
                    height: 1.5,
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

class _GuideStepData {
  const _GuideStepData({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;
}

class _GuideStepCard extends StatelessWidget {
  const _GuideStepCard({required this.step, required this.isLast});

  final _GuideStepData step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7EAF4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EAF9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  step.icon,
                  color: const Color(0xFF35489A),
                  size: 22,
                ),
              ),
              if (!isLast) ...[
                const SizedBox(height: 7),
                Container(
                  width: 2,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6C914),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP ${step.number}',
                  style: const TextStyle(
                    color: Color(0xFF7A8199),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  step.description,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 12,
                    height: 1.5,
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

class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9DF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2E6AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Still need assistance?',
            style: TextStyle(
              color: Color(0xFF1A2254),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Send a report to the NUtilize support team from the app.',
            style: TextStyle(
              color: Color(0xFF6A6F86),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportIssuePage()),
              ),
              icon: const Icon(Icons.support_agent_rounded, size: 19),
              label: const Text('Contact Support'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF35489A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
