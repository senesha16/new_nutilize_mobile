import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_nutilize_mobile/widgets/experience_rating_prompt.dart';

void main() {
  testWidgets('submits the selected star rating', (WidgetTester tester) async {
    int? submittedRating;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ExperienceRatingDialog(
                  onSubmit: (rating) async {
                    submittedRating = rating;
                  },
                ),
              ),
              child: const Text('Open rating'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open rating'));
    await tester.pumpAndSettle();

    expect(
      find.text('Liking your experience using the app? Feel free to rate us'),
      findsOneWidget,
    );
    for (var rating = 1; rating <= 5; rating++) {
      expect(
        find.byKey(ValueKey('experience_rating_star_$rating')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('experience_rating_star_4')));
    await tester.pumpAndSettle();
    expect(find.text('4 out of 5 stars'), findsOneWidget);

    await tester.tap(find.text('Submit rating'));
    await tester.pumpAndSettle();

    expect(submittedRating, 4);
    expect(find.byType(ExperienceRatingDialog), findsNothing);
  });

  testWidgets('Maybe later dismisses the rating prompt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => ExperienceRatingDialog(
                  onSubmit: (_) async {},
                ),
              ),
              child: const Text('Open rating'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open rating'));
    await tester.pumpAndSettle();
    expect(find.byType(ExperienceRatingDialog), findsOneWidget);

    await tester.tap(find.text('Maybe later'));
    await tester.pumpAndSettle();
    expect(find.byType(ExperienceRatingDialog), findsNothing);
  });
}
