import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_nutilize_mobile/features/user/feedback_page.dart';
import 'package:new_nutilize_mobile/features/user/profile_page.dart';
import 'package:new_nutilize_mobile/services/feedback_service.dart';

void main() {
  testWidgets('opens the feedback survey from the User page', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: ProfilePage(showBottomNavigation: false)),
    );
    await tester.pumpAndSettle();

    final feedbackButton = find.text('Feedback');
    await tester.tap(feedbackButton);
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackPage), findsOneWidget);
    expect(find.text('Help us improve NUtilize'), findsOneWidget);
    expect(find.text('Submit feedback'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(FeedbackPage), findsNothing);
  });

  testWidgets('requires and submits all four survey answers', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    FeedbackSurveyResponse? submittedResponse;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeedbackPage(
                    onSubmit: (response) async {
                      submittedResponse = response;
                    },
                  ),
                ),
              ),
              child: const Text('Open survey'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open survey'));
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(FilledButton, 'Submit feedback');
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);

    for (final answer in const {
      'navigation': 2,
      'reservation': 3,
      'responsiveness': 4,
      'information': 1,
    }.entries) {
      final answerFinder = find.byKey(
        ValueKey('feedback_${answer.key}_${answer.value}'),
      );
      await tester.tap(answerFinder);
      await tester.pump();
    }
    final commentField = find.byKey(
      const ValueKey('feedback_additional_comments'),
    );
    await tester.enterText(commentField, 'The reservation flow is clear.');
    await tester.tap(submitButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(submittedResponse, isNotNull);
    expect(submittedResponse!.navigationSatisfaction, 2);
    expect(submittedResponse!.reservationSatisfaction, 3);
    expect(submittedResponse!.responsivenessSatisfaction, 4);
    expect(submittedResponse!.informationSatisfaction, 1);
    expect(
      submittedResponse!.additionalComments,
      'The reservation flow is clear.',
    );
    expect(find.byType(FeedbackPage), findsOneWidget);
    expect(find.text('Thank you for your feedback!'), findsOneWidget);
    expect(
      find.text(
        'Your responses have been submitted and will help us improve NUtilize.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(FeedbackPage), findsNothing);
  });
}
