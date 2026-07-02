import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

Route<T> _fadePageRoute<T>(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class ReservationDetailsPage extends StatelessWidget {
  const ReservationDetailsPage({super.key, required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Reservation Details'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReservationSummaryCard(reservation: reservation),
                    const SizedBox(height: 14),
                    _ApprovalProcessCard(
                      currentStep: reservation.approvalState.progressIndex,
                    ),
                    const SizedBox(height: 18),
                    _ApprovalTimelineCard(reservation: reservation),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE53935),
                              side: const BorderSide(color: Color(0xFFE53935)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text(
                                'Report an Issue',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF6A700),
                              side: const BorderSide(color: Color(0xFFF6A700)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text(
                                'Print / Download',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: 1,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 1) {
                  Navigator.of(context).pop();
                } else if (index == 2) {
                  Navigator.of(
                    context,
                  ).push(_fadePageRoute(const RequestPage()));
                } else if (index == 3) {
                  Navigator.of(context).push(_fadePageRoute(const UserPage()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReservationSummaryCard extends StatelessWidget {
  const _ReservationSummaryCard({required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF2C0), Color(0xFFD7DCF2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reservation In Progress',
            style: TextStyle(
              color: Color(0xFFF6B400),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reservation.reservationTitle,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaItem(
                icon: Icons.calendar_month_rounded,
                label: _formatDate(reservation.date),
              ),
              const _MetaSeparator(),
              _MetaItem(
                icon: Icons.access_time_rounded,
                label: reservation.reservationTime,
              ),
              const _MetaSeparator(),
              _MetaItem(
                icon: Icons.meeting_room_rounded,
                label: reservation.roomNumber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalProcessCard extends StatelessWidget {
  const _ApprovalProcessCard({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval Process',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ProcessProgressBar(currentStep: currentStep),
        ],
      ),
    );
  }
}

class _ProcessProgressBar extends StatelessWidget {
  const _ProcessProgressBar({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final labels = ['Submitted', 'Processing', 'Approved'];

    return Row(
      children: List.generate(labels.length, (index) {
        final bool isCompleted = index <= currentStep;
        final bool isLast = index == labels.length - 1;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF35B556)
                            : const Color(0xFFB5B5B5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF35B556)
                          : const Color(0xFF979797),
                      shape: BoxShape.circle,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: index < currentStep
                              ? const Color(0xFF35B556)
                              : const Color(0xFFB5B5B5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Text(
                  labels[index],
                  textAlign: index == 0
                      ? TextAlign.left
                      : (index == 2 ? TextAlign.right : TextAlign.center),
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ApprovalTimelineCard extends StatelessWidget {
  const _ApprovalTimelineCard({required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    final entries = reservation.approvalTimeline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: entries
            .asMap()
            .entries
            .map(
              (entry) => _TimelineRow(
                entry: entry.value,
                isLast: entry.key == entries.length - 1,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final ReservationTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool completed = entry.isCompleted;
    final Color indicatorColor = completed
        ? const Color(0xFF35B556)
        : const Color(0xFF9E9E9E);
    final Color lineColor = completed
        ? const Color(0xFF35B556)
        : const Color(0xFF9E9E9E);
    final Color titleColor = completed
        ? const Color(0xFF111111)
        : const Color(0xFFB1B1B1);
    final Color bodyColor = completed
        ? const Color(0xFF6A6F86)
        : const Color(0xFFBFBFBF);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.timestamp,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: completed
                      ? const Color(0xFF111111)
                      : const Color(0xFFB1B1B1),
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast) Container(width: 2, height: 34, color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.description,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF111111)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetaSeparator extends StatelessWidget {
  const _MetaSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '|',
        style: TextStyle(
          color: Color(0xFF111111),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
}
