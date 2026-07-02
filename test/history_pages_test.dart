import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_nutilize_mobile/features/request/request_history_page.dart';
import 'package:new_nutilize_mobile/features/request/reservation_history_page.dart';

void main() {
  testWidgets('reservation history page shows search and filter controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ReservationHistoryPage()));

    expect(find.text('Reservation History'), findsWidgets);
    expect(find.text('Search reservations'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });

  testWidgets('request history page shows request filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RequestHistoryPage()));

    expect(find.text('Request History'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
  });
}
