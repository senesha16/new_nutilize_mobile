import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class PersonalDetailsPage extends StatelessWidget {
  const PersonalDetailsPage({super.key});

  static const _details = [
    (Icons.badge_outlined, 'Full Name', 'Juan Agoncillo Dela Cruz'),
    (Icons.email_outlined, 'Email', 'delacruzja@nu-lipa.edu.ph'),
    (
      Icons.school_outlined,
      'Program',
      'Bachelor of Science in Information Technology',
    ),
    (Icons.apartment_outlined, 'Department', 'College of Computer Studies'),
    (Icons.calendar_today_outlined, 'Year Level', '3rd Year'),
    (Icons.phone_outlined, 'Contact Number', '0912 345 6789'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(
              title: 'Personal Details',
              titleKey: ValueKey('personal_details_title'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(),
                    child: const Row(
                      children: [
                        _ProfileAvatar(),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Juan Agoncillo Dela Cruz',
                                style: TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Student Account',
                                style: TextStyle(
                                  color: Color(0xFF6A6F86),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: _cardDecoration(),
                    child: Column(
                      children: List.generate(_details.length, (index) {
                        final detail = _details[index];
                        return Column(
                          children: [
                            _DetailRow(
                              icon: detail.$1,
                              label: detail.$2,
                              value: detail.$3,
                            ),
                            if (index != _details.length - 1)
                              const Divider(
                                height: 1,
                                indent: 68,
                                endIndent: 18,
                              ),
                          ],
                        );
                      }),
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

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFE6EAF9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.person_outline_rounded,
        color: Color(0xFF35489A),
        size: 34,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6FB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF35489A), size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: const [
      BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}
