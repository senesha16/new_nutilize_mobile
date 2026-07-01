import 'package:flutter/material.dart';

class ProfileData {
  const ProfileData({
    required this.fullName,
    required this.studentId,
    required this.email,
    required this.department,
    required this.program,
    required this.yearLevel,
    required this.contactNumber,
    this.imagePath,
  });

  final String fullName;
  final String studentId;
  final String email;
  final String department;
  final String program;
  final String yearLevel;
  final String contactNumber;
  final String? imagePath;

  ProfileData copyWith({
    String? fullName,
    String? studentId,
    String? email,
    String? department,
    String? program,
    String? yearLevel,
    String? contactNumber,
    String? imagePath,
  }) {
    return ProfileData(
      fullName: fullName ?? this.fullName,
      studentId: studentId ?? this.studentId,
      email: email ?? this.email,
      department: department ?? this.department,
      program: program ?? this.program,
      yearLevel: yearLevel ?? this.yearLevel,
      contactNumber: contactNumber ?? this.contactNumber,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class ProfileStore {
  ProfileStore._();

  static final ValueNotifier<ProfileData> listenable =
      ValueNotifier<ProfileData>(
        const ProfileData(
          fullName: 'Juan Agoncillo Dela Cruz',
          studentId: '2022-001245',
          email: 'delacruzja@nu-lipa.edu.ph',
          department: 'College of Computing and Information Sciences',
          program: 'BS Information Technology',
          yearLevel: '3rd Year',
          contactNumber: '+63 917 123 4567',
        ),
      );

  static ProfileData get current => listenable.value;

  static void update(ProfileData profile) {
    listenable.value = profile;
  }
}
