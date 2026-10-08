import 'package:flutter/material.dart';

Future<void> showReservationReturnLockDialog(
  BuildContext context,
  String message,
) {
  const messagePrefix = 'Please accomplish return/settle your reservation:';
  final details = message.startsWith(messagePrefix)
      ? message.substring(messagePrefix.length).trim()
      : message.trim();
  final reservations = details
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.white,
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFD22828).withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_return_rounded,
                  color: Color(0xFFD22828),
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Reservation return required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1C1F2A),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can’t make a new reservation until you return or settle the overdue request.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF626A80),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
              if (reservations.isNotEmpty) ...[
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5FB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE1E5F2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: reservations
                        .map(
                          (reservation) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 2),
                                  child: Icon(
                                    Icons.error_outline_rounded,
                                    color: Color(0xFFD22828),
                                    size: 17,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    reservation,
                                    style: const TextStyle(
                                      color: Color(0xFF34394B),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF35489A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Understood',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
