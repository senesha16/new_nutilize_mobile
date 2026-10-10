import 'package:supabase_flutter/supabase_flutter.dart';

class FeedbackSurveyResponse {
  const FeedbackSurveyResponse({
    required this.navigationSatisfaction,
    required this.reservationSatisfaction,
    required this.responsivenessSatisfaction,
    required this.informationSatisfaction,
    required this.additionalComments,
  });

  final int navigationSatisfaction;
  final int reservationSatisfaction;
  final int responsivenessSatisfaction;
  final int informationSatisfaction;
  final String? additionalComments;
}

class FeedbackService {
  SupabaseClient get _client => Supabase.instance.client;

  Future<void> submitFeedback(FeedbackSurveyResponse response) async {
    await _client.rpc(
      'submit_user_feedback',
      params: {
        'p_navigation_satisfaction': response.navigationSatisfaction,
        'p_reservation_satisfaction': response.reservationSatisfaction,
        'p_responsiveness_satisfaction': response.responsivenessSatisfaction,
        'p_information_satisfaction': response.informationSatisfaction,
        'p_additional_comments': response.additionalComments,
      },
    );
  }
}
