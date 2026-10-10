import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_nutilize_mobile/features/user/profile_page.dart';
import 'package:new_nutilize_mobile/features/user/user_guide_page.dart';

void main() {
  testWidgets('opens the user guide from the User page and returns back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: ProfilePage(showBottomNavigation: false)),
    );
    await tester.pumpAndSettle();

    final helpButton = find.text('Need help?');
    await tester.ensureVisible(helpButton);
    await tester.tap(helpButton);
    await tester.pumpAndSettle();

    expect(find.byType(UserGuidePage), findsOneWidget);
    expect(find.text('Your NUtilize guide'), findsOneWidget);
    expect(find.text('Choose what you need'), findsOneWidget);

    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Follow its progress'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Follow its progress'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Contact Support'),
      250,
      scrollable: scrollable,
    );
    expect(find.text('Contact Support'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(UserGuidePage), findsNothing);
    expect(find.text('Need help?'), findsOneWidget);
  });
}
