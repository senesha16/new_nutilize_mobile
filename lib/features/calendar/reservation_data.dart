import 'package:flutter/foundation.dart';

class ReservationTimelineEntry {
  const ReservationTimelineEntry({
    required this.title,
    required this.status,
    required this.date,
    this.description = '',
    this.timestamp = '',
  });

  final String title;
  final String status;
  final DateTime date;
  final String description;
  final String timestamp;

  bool get isCompleted {
    final normalized = status.toLowerCase();
    return normalized == 'completed' ||
        normalized == 'approved' ||
        normalized == 'submitted' ||
        normalized == 'processing';
  }
}

class ReservationApprovalState {
  const ReservationApprovalState(this.progressIndex);

  final int progressIndex;
}

class ReservationRecord {
  const ReservationRecord({
    this.id,
    required this.reservationTitle,
    required this.roomName,
    required this.reservationType,
    required this.reservationStatus,
    required this.date,
    required this.reservationTime,
    this.timeline = const [],
  });

  final String? id;
  final String reservationTitle;
  final String roomName;
  final String reservationType;
  final String reservationStatus;
  final DateTime date;
  final String reservationTime;
  final List<ReservationTimelineEntry> timeline;

  String get stableId =>
      id ??
      '${reservationTitle.toLowerCase()}-${roomName.toLowerCase()}-${date.millisecondsSinceEpoch}';

  String get roomNumber => roomName;

  ReservationApprovalState get approvalState {
    final status = reservationStatus.toLowerCase();
    if (status.contains('approved') || status.contains('completed')) {
      return const ReservationApprovalState(2);
    }
    if (status.contains('pending') || status.contains('processing')) {
      return const ReservationApprovalState(1);
    }
    return const ReservationApprovalState(0);
  }

  List<ReservationTimelineEntry> get approvalTimeline {
    if (timeline.isNotEmpty) return timeline;

    final progress = approvalState.progressIndex;
    return [
      ReservationTimelineEntry(
        title: 'Request Submitted',
        status: 'Completed',
        date: date,
        timestamp: _formatTimestamp(date),
        description: 'Your reservation request was submitted successfully.',
      ),
      ReservationTimelineEntry(
        title: 'Request Processing',
        status: progress >= 1 ? 'Completed' : 'Waiting',
        date: date,
        timestamp: progress >= 1 ? _formatTimestamp(date) : 'Pending',
        description: progress >= 1
            ? 'Your request is being reviewed.'
            : 'Waiting for the request to be reviewed.',
      ),
      ReservationTimelineEntry(
        title: 'Request Approved',
        status: progress >= 2 ? 'Approved' : 'Waiting',
        date: date,
        timestamp: progress >= 2 ? _formatTimestamp(date) : 'Pending',
        description: progress >= 2
            ? 'Your reservation has been approved.'
            : 'Waiting for final approval.',
      ),
    ];
  }
}

class ReservationRepository {
  const ReservationRepository(this.reservations);

  final List<ReservationRecord> reservations;

  factory ReservationRepository.sample(DateTime now) {
    return ReservationRepository([
      ReservationRecord(
        id: 'sample-room-503',
        reservationTitle: 'INF231 Christmas Party',
        roomName: 'Room 503',
        reservationType: 'Venue Reservation',
        reservationStatus: 'Pending Approval',
        date: DateTime(now.year, now.month, now.day + 6),
        reservationTime: '9:00 AM - 12:00 PM',
      ),
      ReservationRecord(
        id: 'sample-conference-room',
        reservationTitle: 'Department Meeting',
        roomName: 'Conference Room',
        reservationType: 'Venue Reservation',
        reservationStatus: 'Approved',
        date: DateTime(now.year, now.month, now.day - 3),
        reservationTime: '1:00 PM - 3:00 PM',
      ),
      ReservationRecord(
        id: 'sample-studio-2',
        reservationTitle: 'Audio Visual Workshop',
        roomName: 'Studio 2',
        reservationType: 'Venue Reservation',
        reservationStatus: 'Rejected',
        date: DateTime(now.year, now.month, now.day - 8),
        reservationTime: '9:30 AM - 11:30 AM',
      ),
    ]);
  }
}

class ReservationActivityStore {
  static final ValueNotifier<List<ReservationRecord>> listenable =
      ValueNotifier<List<ReservationRecord>>([]);

  static List<ReservationRecord> get reservations =>
      List.unmodifiable(listenable.value);

  static void add(ReservationRecord reservation) {
    listenable.value = [reservation, ...listenable.value];
  }

  static void clear() {
    listenable.value = [];
  }
}

String _formatTimestamp(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = date.hour >= 12 ? 'PM' : 'AM';
  return '${date.month}/${date.day}/${date.year}\n$hour:$minute $period';
}
