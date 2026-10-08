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
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/widgets/reservation_return_lock_dialog.dart';

bool canProceedFromProfilePage({String? selectedDepartment}) {
  final department = selectedDepartment?.trim();
  return department != null && department.isNotEmpty;
}

void main() {
  testWidgets('shows the NUtilize login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const NUtilizeApp());

    expect(find.text('Loading NUtilize...'), findsOneWidget);
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

  testWidgets('shows the branded overdue reservation lock dialog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showReservationReturnLockDialog(
                context,
                'Please accomplish return/settle your reservation:\n\n'
                'TEMP OVERDUE LIFECYCLE TEST (return deadline: 2026-10-07 12:07 AM)',
              ),
              child: const Text('Open lock'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open lock'));
    await tester.pumpAndSettle();

    expect(find.text('Reservation return required'), findsOneWidget);
    expect(
      find.textContaining('You can’t make a new reservation'),
      findsOneWidget,
    );
    expect(find.textContaining('TEMP OVERDUE LIFECYCLE TEST'), findsOneWidget);
    expect(find.text('Understood'), findsOneWidget);

    await tester.tap(find.text('Understood'));
    await tester.pumpAndSettle();
    expect(find.text('Reservation return required'), findsNothing);
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
      {
        'office_name': 'Physical Facilities',
        'created_at': '2026-07-20T10:00:00Z',
      },
      {'office_name': 'Security', 'created_at': '2026-07-20T10:01:00Z'},
      {'office_name': 'Program Chair', 'created_at': '2026-07-20T10:02:00Z'},
      {'office_name': 'Item Owner', 'created_at': '2026-07-20T10:03:00Z'},
    ], itemOwnerOfficeId: 42);

    expect(ordered.map((entry) => entry['office_name']), [
      'Item Owner',
      'Program Chair',
      'Security',
      'Physical Facilities',
    ]);
  });

  test(
    'keeps a borrowed item owner ahead of program chair in the timeline UI',
    () {
      final ordered = ReservationService.sortApprovalEntriesForTimeline([
        {'office_name': 'Program Chair', 'created_at': '2026-07-20T10:00:00Z'},
        {'office_name': 'Maria Lerma', 'created_at': '2026-07-20T10:01:00Z'},
        {'office_name': 'SDAO', 'created_at': '2026-07-20T10:02:00Z'},
        {
          'office_name': 'Physical Facilities',
          'created_at': '2026-07-20T10:03:00Z',
        },
      ]);

      expect(ordered.map((entry) => entry['office_name']), [
        'Maria Lerma',
        'Program Chair',
        'SDAO',
        'Physical Facilities',
      ]);
    },
  );

  test(
    'sorts an approval timeline for AVR with item owner before Program Chair',
    () {
      final ordered = ReservationService.sortApprovalEntriesForTimeline([
        {
          'office_name': 'Physical Facilities',
          'created_at': '2026-07-20T10:00:00Z',
        },
        {'office_name': 'Maria Lerma', 'created_at': '2026-07-20T10:01:00Z'},
        {'office_name': 'Program Chair', 'created_at': '2026-07-20T10:02:00Z'},
        {'office_name': 'Security', 'created_at': '2026-07-20T10:03:00Z'},
      ], itemOwnerOfficeId: 42);

      expect(ordered.map((entry) => entry['office_name']), [
        'Maria Lerma',
        'Program Chair',
        'Security',
        'Physical Facilities',
      ]);
    },
  );

  test('places general education ahead of item owners in gym requests', () {
    final ordered = ReservationService.sortApprovalEntriesForTimeline(
      [
        {'office_name': 'Program Chair', 'created_at': '2026-07-20T10:02:00Z'},
        {'office_name': 'Maria Lerma', 'created_at': '2026-07-20T10:03:00Z'},
        {
          'office_name': 'General Education',
          'created_at': '2026-07-20T10:00:00Z',
        },
        {'office_name': 'Security', 'created_at': '2026-07-20T10:04:00Z'},
      ],
      itemOwnerOfficeId: 42,
      generalEducationOfficeId: 99,
    );

    expect(ordered.map((entry) => entry['office_name']), [
      'General Education',
      'Maria Lerma',
      'Program Chair',
      'Security',
    ]);
  });

  test(
    'normalizes gym room types so general education is retained in the approval chain',
    () {
      expect(ReservationService.normalizeRoomType(' gym '), 'gym');
      expect(ReservationService.isGymRoomType(' gym '), isTrue);
      expect(ReservationService.isGymRoomType('Gym'), isTrue);
      expect(ReservationService.isGymRoomType('GYM'), isTrue);
      expect(ReservationService.isGymRoomType('Classroom'), isFalse);
    },
  );

  test(
    'keeps reservations visible while awaiting physical facilities approval',
    () {
      final reservation = ReservationRecord(
        reservationTitle: 'Party',
        roomName: 'Room 101',
        reservationType: 'Venue Reservation',
        reservationStatus: 'Waiting for Physical Facilities Approval',
        date: DateTime.now(),
        reservationTime: '10:00 AM - 12:00 PM',
        userId: 42,
      );

      expect(
        ReservationActivityStore.isVisibleOnCalendar(
          reservation,
          currentUserId: 42,
        ),
        isTrue,
      );
    },
  );

  test(
    'creates approved notifications from the current reservation baseline',
    () {
      final originalUser = AuthService.currentUser;

      AuthService.currentUser = null;
      NotificationActivityStore.ensureSeeded(DateTime.now());
      AuthService.currentUser = {'user_id': 42, 'email': 'user@example.com'};
      ReservationActivityStore.replaceAll([
        ReservationRecord(
          id: 'approved-1',
          userId: 42,
          reservationTitle: 'Approved request',
          roomName: 'Room 101',
          reservationType: 'Venue Reservation',
          reservationStatus: 'Approved',
          date: DateTime.now(),
          reservationTime: '10:00 AM - 12:00 PM',
        ),
      ]);

      NotificationActivityStore.syncFromReservations(DateTime.now());

      expect(
        NotificationActivityStore.notifications.any(
          (notification) =>
              notification.category == NotificationCategory.reservationApproved,
        ),
        isTrue,
      );

      AuthService.currentUser = originalUser;
      NotificationActivityStore.clear();
    },
  );

  test('profile requires a department before proceeding', () {
    expect(canProceedFromProfilePage(selectedDepartment: null), isFalse);
    expect(canProceedFromProfilePage(selectedDepartment: '   '), isFalse);
    expect(
      canProceedFromProfilePage(selectedDepartment: 'BS Computer Science'),
      isTrue,
    );
  });

  test('hides cancelled reservations from the calendar', () {
    final reservation = ReservationRecord(
      reservationTitle: 'Cancelled Party',
      roomName: 'Room 511',
      reservationType: 'Venue Reservation',
      reservationStatus: 'Cancelled',
      date: DateTime.now(),
      reservationTime: '8:00 AM - 10:00 AM',
      userId: 42,
    );

    expect(
      ReservationActivityStore.isVisibleOnCalendar(
        reservation,
        currentUserId: 42,
      ),
      isFalse,
    );
  });

  test('prefers the latest approval row when overall status is stale', () {
    final approvalRows = [
      {'status': 'Pending', 'created_at': '2026-07-20T10:00:00Z'},
      {'status': 'Approved', 'created_at': '2026-07-20T11:00:00Z'},
      {'status': 'Rejected', 'created_at': '2026-07-20T12:00:00Z'},
    ];

    expect(
      ReservationService.resolveApprovalStatusFromRows(
        overallStatus: 'Pending Approval',
        approvalRows: approvalRows,
      ),
      'Rejected',
    );
  });

  test(
    'keeps the reservation pending while any approval office is pending',
    () {
      expect(
        ReservationService.resolveApprovalStatusFromRows(
          overallStatus: 'Approved',
          approvalRows: [
            {'status': 'Approved', 'updated_at': '2026-08-20T08:00:00Z'},
            {'status': 'Pending', 'updated_at': '2026-08-20T08:01:00Z'},
            {'status': 'Pending', 'updated_at': '2026-08-20T08:02:00Z'},
          ],
        ),
        'Pending Approval',
      );
    },
  );

  test(
    'marks the reservation approved only after every approval office approves',
    () {
      expect(
        ReservationService.resolveApprovalStatusFromRows(
          overallStatus: 'Pending Approval',
          approvalRows: [
            {'status': 'Approved'},
            {'status': 'Approved'},
            {'status': 'Accepted'},
          ],
        ),
        'Approved',
      );
    },
  );

  test('keeps reservation pending until every office approves', () {
    expect(
      ReservationService.resolveApprovalStatusFromRows(
        overallStatus: 'Approved',
        approvalRows: [
          {'status': 'Approved', 'updated_at': '2026-07-20T11:00:00Z'},
          {'status': 'Pending', 'updated_at': '2026-07-20T10:00:00Z'},
          {'status': 'Pending', 'updated_at': '2026-07-20T10:00:00Z'},
        ],
      ),
      'Pending Approval',
    );
  });

  test('preserves timeout, overdue, and returned lifecycle states', () {
    for (final status in ['Timed Out', 'Overdue', 'returned']) {
      expect(
        ReservationService.resolveApprovalStatusFromRows(
          overallStatus: status,
          approvalRows: [
            {'status': 'Pending'},
          ],
        ),
        status,
      );
    }
  });

  test('shows overdue reservations before upcoming recent activity', () {
    final previousUser = AuthService.currentUser;
    final previousReservations = ReservationActivityStore.reservations;
    final now = DateTime(2026, 10, 8);
    final overdue = ReservationRecord(
      id: 'overdue-test',
      userId: 598,
      reservationTitle: 'Overdue test reservation',
      roomName: 'Test Room',
      reservationType: 'Venue Reservation',
      reservationStatus: 'Overdue',
      date: now.subtract(const Duration(days: 2)),
      reservationTime: '8:00 AM - 9:00 AM',
      lastUpdatedAt: now,
    );
    final upcoming = ReservationRecord(
      id: 'upcoming-test',
      userId: 598,
      reservationTitle: 'Upcoming test reservation',
      roomName: 'Test Room',
      reservationType: 'Venue Reservation',
      reservationStatus: 'Approved',
      date: now.add(const Duration(days: 1)),
      reservationTime: '8:00 AM - 9:00 AM',
    );

    AuthService.currentUser = {'user_id': 598};
    ReservationActivityStore.replaceAll([
      upcoming,
      overdue,
    ], syncNotifications: false);

    try {
      final recent = recentReservations(now, limit: 3);
      expect(recent.first.stableId, overdue.stableId);

      final overdueNotification = NotificationRecord(
        id: 'overdue-notification-test',
        category: NotificationCategory.reservationOverdue,
        title: 'Reservation Overdue',
        description: 'Please return or settle this reservation.',
        date: now,
        targetKind: NotificationTargetKind.reservation,
        reservation: overdue,
      );
      expect(overdueNotification.accentColor, const Color(0xFFD22828));
    } finally {
      AuthService.currentUser = previousUser;
      ReservationActivityStore.replaceAll(
        previousReservations,
        syncNotifications: false,
      );
    }
  });

  test(
    'keeps completed and returned states distinct from pending and cancelled',
    () {
      expect(
        ReservationService.resolveApprovalStatusFromRows(
          overallStatus: 'Pending Approval',
          approvalRows: [
            {'status': 'Completed', 'updated_at': '2026-07-20T10:00:00Z'},
            {'status': 'Completed', 'updated_at': '2026-07-20T11:00:00Z'},
          ],
        ),
        'Completed',
      );

      expect(
        ReservationService.resolveApprovalStatusFromRows(
          overallStatus: 'Pending Approval',
          approvalRows: [
            {'status': 'Pending', 'updated_at': '2026-07-20T10:00:00Z'},
            {'status': 'Returned', 'updated_at': '2026-07-20T11:00:00Z'},
          ],
        ),
        'Returned',
      );
    },
  );

  test('clamps item usage to the valid zero-to-total range', () {
    expect(ReservationService.normalizeItemUsage(280, 300), 280);
    expect(ReservationService.normalizeItemUsage(280, -5), 0);
    expect(ReservationService.normalizeItemUsage(280, 20), 20);
    expect(ReservationService.normalizeAvailableQuantity(280, 300), 0);
    expect(ReservationService.normalizeAvailableQuantity(280, 20), 260);
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
