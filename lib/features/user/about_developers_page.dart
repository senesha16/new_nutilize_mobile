import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

class AboutDevelopersPage extends StatelessWidget {
  const AboutDevelopersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final developers = [
      _Developer(
        name: 'Juan Agoncillo Dela Cruz',
        role: 'Lead Frontend Developer',
        course: 'BSIT - 3rd Year',
        email: 'delacruzja@nu-lipa.edu.ph',
        description:
            'Juan focuses on building a clean and intuitive user experience for reservation flows and support features.',
      ),
      _Developer(
        name: 'Maria Santos',
        role: 'UI/UX & QA',
        course: 'BSIT - 3rd Year',
        email: 'santosm@nu-lipa.edu.ph',
        description:
            'Maria helps shape the app’s visual consistency and ensures each flow is polished and easy to use.',
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'NUtilize'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  const Text(
                    'About the Developers',
                    key: ValueKey('about_developers_title'),
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'The team behind NUtilize is focused on creating practical, student-centered tools for campus operations.',
                    style: TextStyle(
                      color: Color(0xFF6A6F86),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                          'Meet the Team',
                          key: ValueKey('about_developers_team_heading'),
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...developers.map(
                          (developer) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _DeveloperCard(developer: developer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppBottomNav(
              selectedIndex: AppShellScope.maybeOf(context)?.currentIndex ?? 3,
              onTap: AppShellScope.maybeOf(context)?.onTabSelected ?? (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard({required this.developer});

  final _Developer developer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: Container(
              width: 60,
              height: 60,
              color: const Color(0xFFE6EAF9),
              child: Image.asset(
                'assets/images/nutilize_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  developer.name,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  developer.role,
                  style: const TextStyle(
                    color: Color(0xFF35489A),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  developer.course,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  developer.email,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  developer.description,
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

class _Developer {
  const _Developer({
    required this.name,
    required this.role,
    required this.course,
    required this.email,
    required this.description,
  });

  final String name;
  final String role;
  final String course;
  final String email;
  final String description;
}
