import 'package:flutter_test/flutter_test.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

void main() {
  group('Program Chair role mapping', () {
    const rolesByProgramId = {
      1: 'PC_MultimediaArts',
      2: 'PC_Architecture',
      3: 'PC_CivilEngineering',
      4: 'PC_ComputerScience',
      5: 'PC_ComputerEngineering',
      6: 'PC_InformationTechnology',
      7: 'PC_Accountancy',
      8: 'PC_FinancialManagement',
      9: 'PC_MarketingManagement',
      10: 'PC_ManagementAccounting',
      11: 'PC_TourismManagement',
      12: 'PC_Psychology',
      13: 'PC_MedicalTechnology',
      14: 'PC_Nursing',
    };

    test('maps every supported role to its academic program', () {
      for (final entry in rolesByProgramId.entries) {
        expect(
          AuthService.programIdForProgramChairRole(entry.value),
          entry.key,
          reason: entry.value,
        );
      }
    });

    group('Dean role mapping', () {
      test(
        'recognizes the three school-scoped Dean roles case-insensitively',
        () {
          for (final role in ['Dean_SACE', 'Dean_SABM', 'Dean_SAHS']) {
            expect(AuthService.isDeanRole(role), isTrue, reason: role);
            expect(AuthService.isDeanRole('  ${role.toLowerCase()}  '), isTrue);
          }
        },
      );

      test('does not classify unrelated roles as Deans', () {
        expect(AuthService.isDeanRole('dean'), isFalse);
        expect(AuthService.isDeanRole('faculty'), isFalse);
        expect(AuthService.isDeanRole('Dean_Unknown'), isFalse);
        expect(AuthService.isDeanRole(null), isFalse);
      });
    });

    test(
      'matches role names case-insensitively and ignores surrounding spaces',
      () {
        expect(
          AuthService.programIdForProgramChairRole('  pc_accountancy  '),
          7,
        );
      },
    );

    test('does not recognize legacy or unrelated roles as a program chair', () {
      expect(AuthService.programIdForProgramChairRole('pc_admin'), isNull);
      expect(AuthService.programIdForProgramChairRole('faculty'), isNull);
      expect(
        AuthService.programIdForProgramChairRole('PC_UnknownProgram'),
        isNull,
      );
      expect(AuthService.programIdForProgramChairRole(null), isNull);
    });
  });

  group('Program affiliation mapping', () {
    test(
      'recognizes the supported IT specialization as Information Technology',
      () {
        expect(
          AuthService.programIdForAffiliation(
            AuthService.itSpecializationLabel,
          ),
          6,
        );
      },
    );

    test('requires a recognized affiliation for routing', () {
      expect(AuthService.programIdForAffiliation(null), isNull);
      expect(AuthService.programIdForAffiliation('Student'), isNull);
      expect(AuthService.programIdForAffiliation('Unknown program'), isNull);
    });
  });
}
