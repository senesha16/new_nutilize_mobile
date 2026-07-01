import 'package:flutter/material.dart';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class ReservationTimelineEntry {
  const ReservationTimelineEntry({
    required this.timestamp,
    required this.title,
    required this.description,
    required this.isCompleted,
  });

  final String timestamp;
  final String title;
  final String description;
  final bool isCompleted;
}

enum ReservationApprovalState {
  pending,
  processing,
  approved;

  int get progressIndex {
    switch (this) {
      case ReservationApprovalState.pending:
        return 0;
      case ReservationApprovalState.processing:
        return 1;
      case ReservationApprovalState.approved:
        return 2;
    }
  }
}

class ReservationRecord {
  const ReservationRecord({
    required this.id,
    required this.date,
    required this.roomName,
    required this.reservationType,
    required this.reservationTitle,
    required this.reservationTime,
    required this.reservationStatus,
    required this.roomNumber,
    required this.approvalState,
    required this.approvalTimeline,
  });

  final String id;
  final DateTime date;
  final String roomName;
  final String reservationType;
  final String reservationTitle;
  final String reservationTime;
  final String reservationStatus;
  final String roomNumber;
  final ReservationApprovalState approvalState;
  final List<ReservationTimelineEntry> approvalTimeline;

  ReservationRecord copyWith({
    String? id,
    DateTime? date,
    String? roomName,
    String? reservationType,
    String? reservationTitle,
    String? reservationTime,
    String? reservationStatus,
    String? roomNumber,
    ReservationApprovalState? approvalState,
    List<ReservationTimelineEntry>? approvalTimeline,
  }) {
    return ReservationRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      roomName: roomName ?? this.roomName,
      reservationType: reservationType ?? this.reservationType,
      reservationTitle: reservationTitle ?? this.reservationTitle,
      reservationTime: reservationTime ?? this.reservationTime,
      reservationStatus: reservationStatus ?? this.reservationStatus,
      roomNumber: roomNumber ?? this.roomNumber,
      approvalState: approvalState ?? this.approvalState,
      approvalTimeline: approvalTimeline ?? this.approvalTimeline,
    );
  }
}

class ReservationActivityStore {
  ReservationActivityStore._();

  static final ValueNotifier<List<ReservationRecord>> _latestReservations =
      ValueNotifier<List<ReservationRecord>>(<ReservationRecord>[]);

  static ValueNotifier<List<ReservationRecord>> get listenable =>
      _latestReservations;

  static ReservationRecord? get latest {
    if (_latestReservations.value.isEmpty) {
      return null;
    }
    return _latestReservations.value.first;
  }

  static void addReservation(ReservationRecord reservation) {
    final updated = <ReservationRecord>[
      reservation,
      ..._latestReservations.value.where((item) => item.id != reservation.id),
    ];
    _latestReservations.value = updated;
  }

  static void upsertReservation(ReservationRecord reservation) {
    final updated = List<ReservationRecord>.from(_latestReservations.value);
    final index = updated.indexWhere((item) => item.id == reservation.id);
    if (index == -1) {
      updated.insert(0, reservation);
    } else {
      updated[index] = reservation;
    }
    _latestReservations.value = updated;
  }

  static void updateReservationStatus({
    required String id,
    required String status,
    required ReservationApprovalState approvalState,
    List<ReservationTimelineEntry>? approvalTimeline,
  }) {
    final updated = List<ReservationRecord>.from(_latestReservations.value);
    final index = updated.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    final current = updated[index];
    updated[index] = current.copyWith(
      reservationStatus: status,
      approvalState: approvalState,
      approvalTimeline: approvalTimeline,
    );
    _latestReservations.value = updated;
  }

  static void removeReservation(String id) {
    _latestReservations.value = _latestReservations.value
        .where((item) => item.id != id)
        .toList();
  }
}

class ReservationRepository {
  ReservationRepository._(this._reservations);

  factory ReservationRepository.sample(DateTime referenceDate) {
    final DateTime today = _dateOnly(referenceDate);
    final DateTime currentMonthStart = DateTime(today.year, today.month, 1);

    return ReservationRepository._(<ReservationRecord>[
      ReservationRecord(
        id: 'sample-2026-07-01-001',
        date: DateTime(currentMonthStart.year, currentMonthStart.month, 1),
        roomName: 'Room 503',
        reservationType: 'Venue Reservation',
        reservationTitle: 'INF231 Christmas Party',
        reservationTime: '9:00 AM - 12:00 PM',
        reservationStatus: 'Pending Approval',
        roomNumber: '503',
        approvalState: ReservationApprovalState.processing,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '12:01 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '12:04 AM',
            title: 'Request Logged',
            description:
                'Your reservation request has been logged and forwarded for approval.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '4:03 AM',
            title: 'Approved by General Education',
            description: 'Your reservation request has been approved.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '4:24 AM',
            title: 'Approved by Item Owner',
            description: 'Your reservation request has been approved.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Approval by Program Chair',
            description:
                'Your reservation request is waiting for the next review.',
            isCompleted: false,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-002',
        date: DateTime(currentMonthStart.year, currentMonthStart.month, 3),
        roomName: 'Conference Room',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Department Meeting',
        reservationTime: '1:00 PM - 3:00 PM',
        reservationStatus: 'Approved',
        roomNumber: '204',
        approvalState: ReservationApprovalState.approved,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '8:00 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '8:30 AM',
            title: 'Request Logged',
            description:
                'Your reservation request has been logged and forwarded for approval.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '10:15 AM',
            title: 'Approved by Office',
            description: 'Your reservation request has been approved.',
            isCompleted: true,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-003',
        date: DateTime(currentMonthStart.year, currentMonthStart.month, 8),
        roomName: 'Studio 2',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Audio Visual Workshop',
        reservationTime: '9:30 AM - 11:30 AM',
        reservationStatus: 'Processing',
        roomNumber: '2',
        approvalState: ReservationApprovalState.processing,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '9:00 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '9:10 AM',
            title: 'Request Logged',
            description:
                'Your reservation request has been logged and forwarded for approval.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Awaiting Review',
            description:
                'Your reservation request is waiting for the next review.',
            isCompleted: false,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-004',
        date: DateTime(currentMonthStart.year, currentMonthStart.month, 12),
        roomName: 'Meeting Room A',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Faculty Consultation',
        reservationTime: '2:00 PM - 4:00 PM',
        reservationStatus: 'Pending Approval',
        roomNumber: 'A',
        approvalState: ReservationApprovalState.pending,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '12:01 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Request Logged',
            description: 'Your reservation request will be reviewed shortly.',
            isCompleted: false,
          ),
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Approval Pending',
            description:
                'Approval steps will appear here once the request moves forward.',
            isCompleted: false,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-005',
        date: DateTime(currentMonthStart.year, currentMonthStart.month, 15),
        roomName: 'Innovation Lab',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Research Demo',
        reservationTime: '8:00 AM - 10:00 AM',
        reservationStatus: 'Approved',
        roomNumber: 'Lab 4',
        approvalState: ReservationApprovalState.approved,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '7:00 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '7:30 AM',
            title: 'Request Logged',
            description:
                'Your reservation request has been logged and forwarded for approval.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '8:10 AM',
            title: 'Approved by Item Owner',
            description: 'Your reservation request has been approved.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '8:30 AM',
            title: 'Approved by General Education',
            description: 'Your reservation request has been approved.',
            isCompleted: true,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-006',
        date: DateTime(currentMonthStart.year, currentMonthStart.month, 21),
        roomName: 'Board Room',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Planning Session',
        reservationTime: '10:30 AM - 12:30 PM',
        reservationStatus: 'Processing',
        roomNumber: 'B',
        approvalState: ReservationApprovalState.processing,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '10:00 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '10:05 AM',
            title: 'Request Logged',
            description:
                'Your reservation request has been logged and forwarded for approval.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Under Review',
            description: 'Your reservation request is currently under review.',
            isCompleted: false,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-007',
        date: DateTime(currentMonthStart.year, currentMonthStart.month + 1, 2),
        roomName: 'Civic Center Room',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Community Event',
        reservationTime: '11:00 AM - 1:00 PM',
        reservationStatus: 'Pending Approval',
        roomNumber: '12',
        approvalState: ReservationApprovalState.pending,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: 'Pending',
            title: 'Request Logged',
            description:
                'Your reservation request will be logged for approval.',
            isCompleted: false,
          ),
        ],
      ),
      ReservationRecord(
        id: 'sample-2026-07-01-008',
        date: DateTime(currentMonthStart.year, currentMonthStart.month - 1, 28),
        roomName: 'Room 618',
        reservationType: 'Venue Reservation',
        reservationTitle: 'Graduation Rehearsal',
        reservationTime: '10:00 AM - 12:00 PM',
        reservationStatus: 'Approved',
        roomNumber: '618',
        approvalState: ReservationApprovalState.approved,
        approvalTimeline: const [
          ReservationTimelineEntry(
            timestamp: '9:00 AM',
            title: 'Request Submitted',
            description: 'Your reservation request has been submitted.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '9:20 AM',
            title: 'Request Logged',
            description:
                'Your reservation request has been logged and forwarded for approval.',
            isCompleted: true,
          ),
          ReservationTimelineEntry(
            timestamp: '10:15 AM',
            title: 'Approved by Office',
            description: 'Your reservation request has been approved.',
            isCompleted: true,
          ),
        ],
      ),
    ]);
  }

  final List<ReservationRecord> _reservations;

  List<ReservationRecord> reservationsForDate(DateTime date) {
    final DateTime targetDate = _dateOnly(date);
    final matches = _reservations
        .where((reservation) => _sameDay(reservation.date, targetDate))
        .toList();
    matches.sort(
      (left, right) => left.reservationTime.compareTo(right.reservationTime),
    );
    return matches;
  }

  Map<DateTime, List<ReservationRecord>> groupedReservations() {
    final Map<DateTime, List<ReservationRecord>> grouped = {};
    for (final reservation in _reservations) {
      final DateTime key = _dateOnly(reservation.date);
      grouped.putIfAbsent(key, () => <ReservationRecord>[]).add(reservation);
    }
    return grouped;
  }

  static bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
