import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';

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
    this.userId,
    required this.reservationTitle,
    required this.roomName,
    required this.reservationType,
    required this.reservationStatus,
    required this.date,
    required this.reservationTime,
    this.timeline = const [],
  });

  final String? id;
  final int? userId;
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

  String get approvalSummary {
    if (timeline.isEmpty) {
      return 'Waiting for approval.';
    }

    String? lastApproved;
    String? nextPending;
    String? rejectedBy;

    for (final entry in timeline.skip(1)) {
      if (entry.status.toLowerCase() == 'rejected' ||
          entry.status.toLowerCase() == 'denied') {
        rejectedBy = entry.title;
        break;
      }
      if (!entry.isCompleted) {
        nextPending = entry.title;
        break;
      }
      lastApproved = entry.title;
    }

    if (rejectedBy != null) {
      return 'Your request was rejected by $rejectedBy.';
    }
    if (nextPending != null) {
      if (lastApproved != null) {
        return 'Approved by $lastApproved, now waiting for $nextPending.';
      }
      return 'Waiting for approval from $nextPending.';
    }
    return 'All approvals complete.';
  }

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
    NotificationActivityStore.syncFromReservations();
  }

  static void upsert(ReservationRecord reservation) {
    final updated = [...listenable.value];
    final index = updated.indexWhere(
      (item) => item.stableId == reservation.stableId,
    );
    if (index == -1) {
      updated.insert(0, reservation);
    } else {
      updated[index] = reservation;
    }
    listenable.value = updated;
    NotificationActivityStore.syncFromReservations();
  }

  static void replaceAll(List<ReservationRecord> reservations) {
    listenable.value = List<ReservationRecord>.from(reservations);
    NotificationActivityStore.syncFromReservations();
  }

  static void removeById(String stableId) {
    listenable.value = listenable.value
        .where((reservation) => reservation.stableId != stableId)
        .toList();
    NotificationActivityStore.syncFromReservations();
  }

  static void clear() {
    listenable.value = [];
    NotificationActivityStore.syncFromReservations();
  }
}

List<ReservationRecord> collectReservations(DateTime now) {
  final combined = <ReservationRecord>[];
  final seenIds = <String>{};
  final currentUserId = AuthService.currentUser?['user_id'] as int?;

  for (final reservation in [
    ...ReservationActivityStore.listenable.value,
    ...ReservationRepository.sample(now).reservations,
  ]) {
    if (currentUserId != null && reservation.userId != currentUserId) {
      continue;
    }

    if (seenIds.add(reservation.stableId)) {
      combined.add(reservation);
    }
  }

  combined.sort((a, b) => b.date.compareTo(a.date));
  return combined;
}

List<ReservationRecord> recentReservations(DateTime now, {int limit = 3}) {
  final allReservations = collectReservations(now);
  if (allReservations.length <= limit) {
    return allReservations;
  }
  return allReservations.take(limit).toList();
}

Map<DateTime, int> reservationCountsByDate(
  List<ReservationRecord> reservations,
) {
  final counts = <DateTime, int>{};
  for (final reservation in reservations) {
    final key = DateTime(
      reservation.date.year,
      reservation.date.month,
      reservation.date.day,
    );
    counts[key] = (counts[key] ?? 0) + 1;
  }
  return counts;
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

enum NotificationCategory {
  reservationSubmitted,
  reservationApproved,
  reservationRejected,
  reservationCancelled,
  reservationReminder,
  announcement,
  roomMaintenance,
  systemUpdate,
}

enum NotificationTargetKind { reservation, announcement, room, none }

class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.date,
    required this.targetKind,
    this.isRead = false,
    this.reservation,
    this.detailTitle,
    this.detailBody,
    this.roomName,
    this.roomDetails,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String description;
  final DateTime date;
  final NotificationTargetKind targetKind;
  final bool isRead;
  final ReservationRecord? reservation;
  final String? detailTitle;
  final String? detailBody;
  final String? roomName;
  final String? roomDetails;

  NotificationRecord copyWith({
    bool? isRead,
    DateTime? date,
    String? title,
    String? description,
    String? detailTitle,
    String? detailBody,
    String? roomName,
    String? roomDetails,
  }) {
    return NotificationRecord(
      id: id,
      category: category,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      targetKind: targetKind,
      isRead: isRead ?? this.isRead,
      reservation: reservation,
      detailTitle: detailTitle ?? this.detailTitle,
      detailBody: detailBody ?? this.detailBody,
      roomName: roomName ?? this.roomName,
      roomDetails: roomDetails ?? this.roomDetails,
    );
  }

  IconData get icon {
    return switch (category) {
      NotificationCategory.reservationSubmitted => Icons.event_note_rounded,
      NotificationCategory.reservationApproved => Icons.verified_rounded,
      NotificationCategory.reservationRejected => Icons.cancel_rounded,
      NotificationCategory.reservationCancelled => Icons.event_busy_rounded,
      NotificationCategory.reservationReminder =>
        Icons.notifications_active_rounded,
      NotificationCategory.announcement => Icons.campaign_rounded,
      NotificationCategory.roomMaintenance => Icons.construction_rounded,
      NotificationCategory.systemUpdate => Icons.system_update_alt_rounded,
    };
  }

  Color get accentColor {
    return switch (category) {
      NotificationCategory.reservationSubmitted => const Color(0xFF35489A),
      NotificationCategory.reservationApproved => const Color(0xFF2E9D50),
      NotificationCategory.reservationRejected => const Color(0xFFD22828),
      NotificationCategory.reservationCancelled => const Color(0xFFD22828),
      NotificationCategory.reservationReminder => const Color(0xFFF6A700),
      NotificationCategory.announcement => const Color(0xFFE94545),
      NotificationCategory.roomMaintenance => const Color(0xFF6C5CE7),
      NotificationCategory.systemUpdate => const Color(0xFF8A90A8),
    };
  }

  String relativeTimestamp(DateTime now) {
    final difference = now.difference(date);
    if (difference.inMinutes < 1) {
      return 'Just now';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class NotificationRepository {
  const NotificationRepository(this.notifications);

  final List<NotificationRecord> notifications;

  factory NotificationRepository.sample(DateTime now) {
    final reservations = collectReservations(now);

    final reservationNotifications = reservations.asMap().entries.map((entry) {
      final reservation = entry.value;
      final date = now.subtract(Duration(minutes: entry.key * 12));
      final status = reservation.reservationStatus.toLowerCase();
      final category = switch (status) {
        _ when status.contains('approved') =>
          NotificationCategory.reservationApproved,
        _ when status.contains('reject') =>
          NotificationCategory.reservationRejected,
        _ when status.contains('cancel') =>
          NotificationCategory.reservationCancelled,
        _ => NotificationCategory.reservationSubmitted,
      };
      final title = switch (category) {
        NotificationCategory.reservationApproved => 'Reservation Approved',
        NotificationCategory.reservationRejected => 'Reservation Rejected',
        NotificationCategory.reservationCancelled => 'Reservation Cancelled',
        _ => 'Reservation Submitted',
      };
      final description = switch (category) {
        NotificationCategory.reservationApproved =>
          '${reservation.roomName} has been approved for ${reservation.reservationTime}.',
        NotificationCategory.reservationRejected =>
          '${reservation.roomName} was not approved. Review the details for more information.',
        NotificationCategory.reservationCancelled =>
          '${reservation.roomName} reservation has been cancelled.',
        _ =>
          '${reservation.roomName} has been submitted and is pending review.',
      };

      return NotificationRecord(
        id: 'reservation-${reservation.stableId}',
        category: category,
        title: title,
        description: description,
        date: date,
        targetKind: NotificationTargetKind.reservation,
        isRead: entry.key > 1,
        reservation: reservation,
      );
    }).toList();

    final notifications = [
      ...reservationNotifications,
      NotificationRecord(
        id: 'announcement-room-618',
        category: NotificationCategory.announcement,
        title: 'New Announcement',
        description: 'Room 618 will undergo scheduled maintenance this week.',
        date: now.subtract(const Duration(hours: 3)),
        targetKind: NotificationTargetKind.announcement,
        detailTitle: 'Room 618 Scheduled Maintenance',
        detailBody:
            'Please be advised that Room 618 will undergo scheduled maintenance on June 15, 2026, from 8:00 AM to 5:00 PM. The room will be temporarily unavailable for reservations during this period. Thank you for your understanding.',
      ),
      NotificationRecord(
        id: 'room-maintenance-room-503',
        category: NotificationCategory.roomMaintenance,
        title: 'Room Maintenance',
        description: 'Room 503 has a maintenance update posted.',
        date: now.subtract(const Duration(days: 1, hours: 2)),
        targetKind: NotificationTargetKind.room,
        roomName: 'Room 503',
        roomDetails:
            'Room 503 is temporarily unavailable while routine maintenance is completed.',
      ),
      NotificationRecord(
        id: 'system-update-1',
        category: NotificationCategory.systemUpdate,
        title: 'System Update',
        description:
            'NUtilize has been updated with improved reservation syncing.',
        date: now.subtract(const Duration(days: 2, hours: 1)),
        targetKind: NotificationTargetKind.announcement,
        detailTitle: 'System Update',
        detailBody:
            'NUtilize has been updated with improved reservation syncing and notification delivery for a smoother experience.',
      ),
      NotificationRecord(
        id: 'reservation-reminder-1',
        category: NotificationCategory.reservationReminder,
        title: 'Reservation Reminder',
        description: 'Your upcoming reservation is scheduled for tomorrow.',
        date: now.subtract(const Duration(hours: 7)),
        targetKind: NotificationTargetKind.reservation,
        reservation: reservations.isNotEmpty ? reservations.first : null,
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return NotificationRepository(notifications);
  }
}

class NotificationActivityStore {
  static final ValueNotifier<List<NotificationRecord>> listenable =
      ValueNotifier<List<NotificationRecord>>([]);

  static bool _seeded = false;

  static List<NotificationRecord> get notifications =>
      List.unmodifiable(listenable.value);

  static void ensureSeeded([DateTime? now]) {
    if (!_seeded || listenable.value.isEmpty) {
      syncFromReservations(now);
      _seeded = true;
    }
  }

  static void syncFromReservations([DateTime? now]) {
    final current = now ?? DateTime.now();
    final existing = {
      for (final notification in listenable.value)
        notification.id: notification,
    };
    final fresh = NotificationRepository.sample(current).notifications;
    listenable.value = fresh
        .map(
          (notification) => notification.copyWith(
            isRead: existing[notification.id]?.isRead ?? notification.isRead,
          ),
        )
        .toList();
  }

  static void markAllAsRead() {
    listenable.value = listenable.value
        .map((notification) => notification.copyWith(isRead: true))
        .toList();
  }

  static void markAsRead(String id) {
    listenable.value = listenable.value
        .map(
          (notification) => notification.id == id
              ? notification.copyWith(isRead: true)
              : notification,
        )
        .toList();
  }

  static void removeById(String id) {
    listenable.value = listenable.value
        .where((notification) => notification.id != id)
        .toList();
  }

  static void clear() {
    listenable.value = [];
  }
}
