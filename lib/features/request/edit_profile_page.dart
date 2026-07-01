import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/request/profile_data.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _studentIdController;
  late final TextEditingController _emailController;
  late final TextEditingController _contactNumberController;
  late final TextEditingController _departmentController;
  late final TextEditingController _programController;
  late ProfileData _profile;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    _profile = ProfileStore.current;
    _studentIdController = TextEditingController(text: _profile.studentId);
    _emailController = TextEditingController(text: _profile.email);
    _contactNumberController = TextEditingController(
      text: _profile.contactNumber,
    );
    _departmentController = TextEditingController(text: _profile.department);
    _programController = TextEditingController(text: _profile.program);
    if (_profile.imagePath != null) {
      _selectedImage = XFile(_profile.imagePath!);
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _emailController.dispose();
    _contactNumberController.dispose();
    _departmentController.dispose();
    _programController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final selected = await picker.pickImage(source: ImageSource.gallery);
    if (selected == null) return;
    setState(() {
      _selectedImage = selected;
    });
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _saveChanges() {
    final updatedProfile = _profile.copyWith(
      contactNumber: _contactNumberController.text.trim(),
      department: _departmentController.text.trim(),
      program: _programController.text.trim(),
      imagePath: _selectedImage?.path,
    );

    ProfileStore.update(updatedProfile);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF35489A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: _cancel,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
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
                    GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6EAF9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFF6C914),
                                width: 2,
                              ),
                              image: _selectedImage == null
                                  ? null
                                  : DecorationImage(
                                      image: FileImage(
                                        File(_selectedImage!.path),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            child: _selectedImage == null
                                ? const Icon(
                                    Icons.person_outline_rounded,
                                    color: Color(0xFF35489A),
                                    size: 52,
                                  )
                                : null,
                          ),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF6C914),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF1A2254),
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _pickImage,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF35489A),
                      ),
                      child: const Text(
                        'Change Profile Picture',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _sectionCard(
                title: 'Account Information',
                children: [
                  _field(
                    label: 'Full Name',
                    value: _profile.fullName,
                    readOnly: true,
                    icon: Icons.person_outline_rounded,
                  ),
                  _field(
                    label: 'Student / Faculty ID',
                    controller: _studentIdController,
                    readOnly: true,
                    icon: Icons.badge_outlined,
                  ),
                  _field(
                    label: 'Email (Microsoft Account)',
                    controller: _emailController,
                    readOnly: true,
                    icon: Icons.email_outlined,
                  ),
                  _field(
                    label: 'Contact Number',
                    controller: _contactNumberController,
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  _field(
                    label: 'College / Department',
                    controller: _departmentController,
                    icon: Icons.school_outlined,
                  ),
                  _field(
                    label: 'Program',
                    controller: _programController,
                    icon: Icons.menu_book_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF35489A),
                        side: const BorderSide(color: Color(0xFF94A0D1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF6C914),
                        foregroundColor: const Color(0xFF1A2254),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CalendarPage()));
            } else if (index == 2) {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const RequestPage()));
            } else if (index == 3) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
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
          ...children,
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    IconData? icon,
    TextEditingController? controller,
    String? value,
    bool readOnly = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
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
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  readOnly: readOnly,
                  keyboardType: keyboardType,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: value,
                    hintStyle: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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
