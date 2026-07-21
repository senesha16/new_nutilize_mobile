// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/user/about_developers_page.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/features/user/about_nutilize_page.dart';
import 'package:new_nutilize_mobile/features/user/edit_profile_page.dart';
import 'package:new_nutilize_mobile/features/user/personal_details_page.dart';
import 'package:new_nutilize_mobile/features/user/report_issue_page.dart';
import 'package:new_nutilize_mobile/features/user/request_history_page.dart';
import 'package:new_nutilize_mobile/main.dart';

void main() {
  testWidgets('shows the NUtilize login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NUtilizeApp());

    expect(find.text('Welcome to'), findsOneWidget);
    expect(find.text('Log In with Microsoft'), findsOneWidget);
  });

  testWidgets('shows request history entries and filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RequestHistoryPage()));

    expect(find.text('Request History'), findsOneWidget);
    expect(find.text('Pending'), findsWidgets);
  });

  testWidgets('shows the report issue form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReportIssuePage()));

    expect(find.text('Report an Issue'), findsOneWidget);
    expect(find.text('Issue Category'), findsOneWidget);
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('shows the personal details screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: PersonalDetailsPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('personal_details_title')),
      findsOneWidget,
    );
    expect(find.text('Personal Details'), findsOneWidget);
  });

  testWidgets('shows the edit profile form', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditProfilePage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('edit_profile_title')), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
  });

  testWidgets('shows the about nutilize information', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AboutNutilizePage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('about_nutilize_title')), findsOneWidget);
  });

  testWidgets('shows the developers section', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutDevelopersPage()));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('about_developers_title')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('about_developers_team_heading')),
      findsOneWidget,
    );
    expect(find.text('Juan Agoncillo Dela Cruz'), findsOneWidget);
  });

  test('sorts an approval timeline by workflow order', () {
    final ordered = ReservationService.sortApprovalEntriesForTimeline([
      {'office_name': 'Physical Facilities', 'created_at': '2026-07-20T10:00:00Z'},
      {'office_name': 'Security', 'created_at': '2026-07-20T10:01:00Z'},
      {'office_name': 'Program Chair', 'created_at': '2026-07-20T10:02:00Z'},
      {'office_name': 'Item Owner', 'created_at': '2026-07-20T10:03:00Z'},
    ]);

    expect(
      ordered.map((entry) => entry['office_name']),
      ['Program Chair', 'Item Owner', 'Security', 'Physical Facilities'],
    );
  });

  test('detects newly added or updated notifications', () {
    final previous = <NotificationRecord>[
      NotificationRecord(
        id: 'one',
        category: NotificationCategory.reservationSubmitted,
        title: 'Submitted',
        description: 'First',
        date: DateTime.now(),
        targetKind: NotificationTargetKind.none,
      ),
    ];
    final current = <NotificationRecord>[
      NotificationRecord(
        id: 'one',
        category: NotificationCategory.reservationApproved,
        title: 'Approved',
        description: 'Updated',
        date: DateTime.now(),
        targetKind: NotificationTargetKind.reservation,
        reservation: ReservationRecord(
          reservationTitle: 'Room',
          roomName: 'Room 101',
          reservationType: 'Venue Reservation',
          reservationStatus: 'Approved',
          date: DateTime.now(),
          reservationTime: '',
        ),
      ),
      NotificationRecord(
        id: 'two',
        category: NotificationCategory.reservationApproved,
        title: 'Approved',
        description: 'Second',
        date: DateTime.now(),
        targetKind: NotificationTargetKind.reservation,
      ),
    ];

    final newIds = NotificationActivityStore.getNewNotificationIds(
      previous,
      current,
    );

    expect(newIds, ['one', 'two']);
  });
}
