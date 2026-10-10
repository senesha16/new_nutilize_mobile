import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/top_message_banner.dart';

Future<void> showExperienceRatingPrompt(
  BuildContext context, {
  required int reservationId,
}) async {
  final service = ReservationService();
  bool shouldPrompt;
  try {
    shouldPrompt = await service.shouldPromptExperienceRating(reservationId);
  } catch (error) {
    debugPrint('Could not check experience-rating eligibility: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your reservation was submitted, but the rating prompt could not be loaded.',
          ),
        ),
      );
    }
    return;
  }

  if (!context.mounted || !shouldPrompt) return;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => ExperienceRatingDialog(
      onSubmit: (rating) => service.submitExperienceRating(
        reservationId: reservationId,
        rating: rating,
      ),
    ),
  );

  if (saved == true && context.mounted) {
    showTopMessage(
      context,
      'Thank you for rating your experience!',
      icon: Icons.star_rounded,
    );
  }
}

class ExperienceRatingDialog extends StatefulWidget {
  const ExperienceRatingDialog({super.key, required this.onSubmit});

  final Future<void> Function(int rating) onSubmit;

  @override
  State<ExperienceRatingDialog> createState() => _ExperienceRatingDialogState();
}

class _ExperienceRatingDialogState extends State<ExperienceRatingDialog> {
  int _rating = 0;
  bool _isSaving = false;
  String? _error;

  Future<void> _saveRating() async {
    if (_rating == 0 || _isSaving) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_rating);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Could not save experience rating: $error');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = 'Your rating could not be saved. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.topRight,
            heightFactor: 0.5,
            child: IconButton(
              tooltip: 'Close',
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF7A8199)),
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.rate_review_rounded,
              color: Color(0xFF35489A),
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Liking your experience using the app? Feel free to rate us',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF1A2254),
              fontSize: 19,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your feedback helps us improve NUtilize.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6A6F86),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final value = index + 1;
              return IconButton(
                key: ValueKey('experience_rating_star_$value'),
                tooltip: '$value ${value == 1 ? 'star' : 'stars'}',
                onPressed: _isSaving
                    ? null
                    : () => setState(() {
                        _rating = value;
                        _error = null;
                      }),
                iconSize: 37,
                padding: const EdgeInsets.symmetric(horizontal: 3),
                constraints: const BoxConstraints(minWidth: 42, minHeight: 48),
                icon: Icon(
                  value <= _rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: value <= _rating
                      ? const Color(0xFFF2B705)
                      : const Color(0xFFB8BED0),
                ),
              );
            }),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LOW',
                style: TextStyle(
                  color: Color(0xFF8A90A8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'HIGH',
                style: TextStyle(
                  color: Color(0xFF8A90A8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 7),
            Text(
              '$_rating out of 5 stars',
              style: const TextStyle(
                color: Color(0xFF35489A),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFC0392B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _rating == 0 || _isSaving ? null : _saveRating,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF35489A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD9DDEC),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Submit rating',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Maybe later',
              style: TextStyle(
                color: Color(0xFF6A6F86),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
