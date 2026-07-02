import 'dart:async';

import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_details_page.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  static const _monthNames = [
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

  late final ReservationRepository _reservationRepository;

  DateTime _today = DateTime.now();
  DateTime _visibleMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    _reservationRepository = ReservationRepository.sample(_today);
    _scheduleMidnightUpdate();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightUpdate() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (!mounted) return;
      setState(() {
        _today = DateTime.now();
        _visibleMonth = DateTime(_today.year, _today.month, 1);
        _selectedDate = _today;
      });
      _scheduleMidnightUpdate();
    });
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _coerceSelectedDateToVisibleMonth() {
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final day = _selectedDate.day > daysInMonth
        ? daysInMonth
        : _selectedDate.day;
    return DateTime(_visibleMonth.year, _visibleMonth.month, day);
  }

  List<List<_CalendarCell>> _buildWeeks(DateTime date) {
    final weeks = <List<_CalendarCell>>[];
    final firstOfMonth = DateTime(date.year, date.month, 1);
    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;
    final firstWeekday = firstOfMonth.weekday % 7;

    var week = <_CalendarCell>[];
    for (var index = 0; index < firstWeekday; index++) {
      week.add(const _CalendarCell(date: null, label: ''));
    }

    for (var day = 1; day <= daysInMonth; day++) {
      week.add(
        _CalendarCell(
          date: DateTime(date.year, date.month, day),
          label: day.toString(),
        ),
      );
      if (week.length == 7) {
        weeks.add(week);
        week = <_CalendarCell>[];
      }
    }

    if (week.isNotEmpty) {
      while (week.length < 7) {
        week.add(const _CalendarCell(date: null, label: ''));
      }
      weeks.add(week);
    }

    return weeks;
  }

  List<ReservationRecord> _allReservations() {
    final combined = <ReservationRecord>[];
    final seenIds = <String>{};

    for (final reservation in [
      ...ReservationActivityStore.listenable.value,
      ..._reservationRepository.reservations,
    ]) {
      if (seenIds.add(reservation.stableId)) {
        combined.add(reservation);
      }
    }

    combined.sort((a, b) => a.date.compareTo(b.date));
    return combined;
  }

  Map<DateTime, int> _reservationCountsByDay(
    List<ReservationRecord> reservations,
  ) {
    final counts = <DateTime, int>{};
    for (final reservation in reservations) {
      final key = _normalizeDate(reservation.date);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<ReservationRecord> _reservationsForDate(DateTime date) {
    final normalized = _normalizeDate(date);
    return _allReservations()
        .where(
          (reservation) => DateUtils.isSameDay(reservation.date, normalized),
        )
        .toList();
  }

  void _goToPreviousMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
      _selectedDate = _coerceSelectedDateToVisibleMonth();
    });
  }

  void _goToNextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
      _selectedDate = _coerceSelectedDateToVisibleMonth();
    });
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel =
        '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}';
    final allReservations = _allReservations();
    final weeks = _buildWeeks(_visibleMonth);
    final reservations = _reservationsForDate(_selectedDate);
    final reservationCounts = _reservationCountsByDay(allReservations);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'NUtilize'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x16000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    monthLabel,
                                    style: const TextStyle(
                                      color: Color(0xFF111111),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Color(0xFF35489A),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _goToPreviousMonth,
                                    child: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: Color(0xFF35489A),
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: _goToNextMonth,
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Color(0xFF35489A),
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              _WeekLabel('SUN'),
                              _WeekLabel('MON'),
                              _WeekLabel('TUE'),
                              _WeekLabel('WED'),
                              _WeekLabel('THU'),
                              _WeekLabel('FRI'),
                              _WeekLabel('SAT'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _CalendarGrid(
                            weeks: weeks,
                            selectedDate: _selectedDate,
                            todayDate: _today,
                            onDaySelected: _onDaySelected,
                            reservationCountsByDate: reservationCounts,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Reservations',
                            style: TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (reservations.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F5FB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No reservations for this date.',
                                style: TextStyle(
                                  color: Color(0xFF7A7A85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          else
                            Column(
                              children: reservations
                                  .map(
                                    (reservation) => Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F5FB),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ReservationDetailsPage(
                                                      reservation: reservation,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF35489A),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      reservation.roomName,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF111111,
                                                        ),
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      reservation
                                                          .reservationTime,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFF7A7A85,
                                                        ),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCell {
  const _CalendarCell({required this.date, required this.label});

  final DateTime? date;
  final String label;
}

class _WeekLabel extends StatelessWidget {
  const _WeekLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFD0D0D6),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.weeks,
    required this.selectedDate,
    required this.todayDate,
    required this.onDaySelected,
    required this.reservationCountsByDate,
  });

  final List<List<_CalendarCell>> weeks;
  final DateTime selectedDate;
  final DateTime todayDate;
  final ValueChanged<DateTime> onDaySelected;
  final Map<DateTime, int> reservationCountsByDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: weeks
          .map(
            (week) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: week
                    .map(
                      (cell) => _DayCell(
                        day: cell.label,
                        date: cell.date,
                        selected:
                            cell.date != null &&
                            DateUtils.isSameDay(cell.date, selectedDate),
                        isToday:
                            cell.date != null &&
                            DateUtils.isSameDay(cell.date, todayDate),
                        hasReservation:
                            cell.date != null &&
                            (reservationCountsByDate[DateTime(
                                      cell.date!.year,
                                      cell.date!.month,
                                      cell.date!.day,
                                    )] ??
                                    0) >
                                0,
                        onTap: cell.date == null
                            ? null
                            : () => onDaySelected(cell.date!),
                      ),
                    )
                    .toList(),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.selected,
    required this.isToday,
    required this.hasReservation,
    required this.onTap,
  });

  final String day;
  final DateTime? date;
  final bool selected;
  final bool isToday;
  final bool hasReservation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (day.isEmpty) {
      return const SizedBox(width: 32, height: 32);
    }

    final content = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF35489A) : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && !selected
                ? Border.all(color: const Color(0xFF35489A), width: 1.2)
                : null,
          ),
          child: Text(
            day,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF111111),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (hasReservation)
          Positioned(
            bottom: 2,
            child: Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF35489A),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );

    if (onTap == null) {
      return content;
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}
