import 'dart:io';

import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/request/edit_profile_page.dart';
import 'package:new_nutilize_mobile/features/request/profile_data.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';

class PersonalDetailsPage extends StatelessWidget {
  const PersonalDetailsPage({super.key});

  Future<void> _openEditProfile(BuildContext context) async {
    final bool? saved = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const EditProfilePage()));

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProfileData>(
      valueListenable: ProfileStore.listenable,
      builder: (context, profile, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFF3F5FB),
          appBar: AppBar(
            backgroundColor: const Color(0xFF35489A),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              'Personal Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
            ),
            actions: [
              TextButton(
                onPressed: () => _openEditProfile(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(4),
              child: Divider(height: 4, thickness: 4, color: Color(0xFFF2C94C)),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6EAF9),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(0xFFF6C914),
                              width: 2,
                            ),
                            image: profile.imagePath == null
                                ? null
                                : DecorationImage(
                                    image: FileImage(File(profile.imagePath!)),
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          child: profile.imagePath == null
                              ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: Color(0xFF35489A),
                                  size: 50,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          profile.fullName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Student Profile',
                          style: TextStyle(
                            color: Color(0xFF6A6F86),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _InfoSection(
                    title: 'Profile Information',
                    items: [
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'Student / Faculty ID',
                        value: profile.studentId,
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email (Microsoft Account)',
                        value: profile.email,
                      ),
                      _InfoRow(
                        icon: Icons.school_outlined,
                        label: 'College / Department',
                        value: profile.department,
                      ),
                      _InfoRow(
                        icon: Icons.menu_book_outlined,
                        label: 'Program',
                        value: profile.program,
                      ),
                      _InfoRow(
                        icon: Icons.class_outlined,
                        label: 'Year Level',
                        value: profile.yearLevel,
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Contact Number',
                        value: profile.contactNumber,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            top: false,
            child: AppBottomNav(
              selectedIndex: 3,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
                } else if (index == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarPage()),
                  );
                } else if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RequestPage()),
                  );
                } else if (index == 3) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
        );
      },
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.items});

  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF4053A7),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9DEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF35489A), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF6A6F86),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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
