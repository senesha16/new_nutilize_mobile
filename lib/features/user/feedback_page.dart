import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/services/feedback_service.dart'
    show FeedbackService, FeedbackSurveyResponse;
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key, this.onSubmit});

  final Future<void> Function(FeedbackSurveyResponse response)? onSubmit;

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final _commentController = TextEditingController();
  final Map<String, int> _answers = {};
  bool _isSubmitting = false;
  String? _error;

  static const _questions = <_FeedbackQuestion>[
    _FeedbackQuestion(
      key: 'navigation',
      text: 'How satisfactory is finding your way around the system?',
    ),
    _FeedbackQuestion(
      key: 'reservation',
      text: 'How satisfactory is the reservation request process?',
    ),
    _FeedbackQuestion(
      key: 'responsiveness',
      text: 'How satisfactory is the system’s speed and responsiveness?',
    ),
    _FeedbackQuestion(
      key: 'information',
      text:
          'How satisfactory is the clarity of reservation information and updates?',
    ),
  ];

  bool get _canSubmit => !_isSubmitting && _answers.length == _questions.length;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final response = FeedbackSurveyResponse(
      navigationSatisfaction: _answers['navigation']!,
      reservationSatisfaction: _answers['reservation']!,
      responsivenessSatisfaction: _answers['responsiveness']!,
      informationSatisfaction: _answers['information']!,
      additionalComments: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );

    try {
      final submit = widget.onSubmit ?? FeedbackService().submitFeedback;
      await submit(response);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _FeedbackThankYouDialog(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('Could not submit user feedback: $error');
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Your feedback could not be submitted. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Feedback'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  const _FeedbackIntroCard(),
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'YOUR EXPERIENCE',
                      style: TextStyle(
                        color: Color(0xFF35489A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  for (final question in _questions) ...[
                    _FeedbackQuestionCard(
                      question: question,
                      selectedValue: _answers[question.key],
                      enabled: !_isSubmitting,
                      onSelected: (value) => setState(() {
                        _answers[question.key] = value;
                        _error = null;
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildCommentCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFC0392B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF35489A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFD9DDEC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Submit feedback',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D172554),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anything else you’d like us to know?',
            style: TextStyle(
              color: Color(0xFF1A2254),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Additional comments (optional)',
            style: TextStyle(color: Color(0xFF777E95), fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('feedback_additional_comments'),
            controller: _commentController,
            enabled: !_isSubmitting,
            maxLines: 4,
            maxLength: 2000,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Type your comments here...',
              hintStyle: const TextStyle(color: Color(0xFF9AA0B2)),
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackThankYouDialog extends StatelessWidget {
  const _FeedbackThankYouDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EDFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: Color(0xFF35489A),
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Thank you for your feedback!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1A2254),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Your responses have been submitted and will help us improve NUtilize.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6A6F86),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF35489A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackIntroCard extends StatelessWidget {
  const _FeedbackIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDFF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.volunteer_activism_rounded, color: Color(0xFF35489A)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Help us improve NUtilize',
                  style: TextStyle(
                    color: Color(0xFF1A2254),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Choose one of the four options for each statement. Your answers are saved securely.',
                  style: TextStyle(
                    color: Color(0xFF59627F),
                    fontSize: 13,
                    height: 1.4,
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

class _FeedbackQuestion {
  const _FeedbackQuestion({required this.key, required this.text});

  final String key;
  final String text;
}

class _FeedbackQuestionCard extends StatelessWidget {
  const _FeedbackQuestionCard({
    required this.question,
    required this.selectedValue,
    required this.enabled,
    required this.onSelected,
  });

  final _FeedbackQuestion question;
  final int? selectedValue;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D172554),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.text,
            style: const TextStyle(
              color: Color(0xFF1A2254),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(4, (index) {
              final value = index + 1;
              final isSelected = selectedValue == value;
              return Expanded(
                child: Center(
                  child: Semantics(
                    label: '$value of 4',
                    selected: isSelected,
                    button: true,
                    child: InkWell(
                      key: ValueKey('feedback_${question.key}_$value'),
                      onTap: enabled ? () => onSelected(value) : null,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? const Color(0xFF35489A)
                              : const Color(0xFFF7F8FC),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF35489A)
                                : const Color(0xFFB8BED0),
                            width: 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Least satisfactory',
                style: TextStyle(color: Color(0xFF777E95), fontSize: 10),
              ),
              Text(
                'Most satisfactory',
                style: TextStyle(color: Color(0xFF777E95), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
