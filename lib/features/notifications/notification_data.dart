import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _formatMonthDay(DateTime date) {
  const monthNames = [
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
  return '${monthNames[date.month - 1]} ${date.day}';
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

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.timestamp,
    this.isRead = false,
    this.reservation,
    this.detailTitle,
    this.detailBody,
    this.detailDateLabel,
  });

  final String id;
  final NotificationCategory category;
  final String title;
  final String description;
  final DateTime timestamp;
  final bool isRead;
  final ReservationRecord? reservation;
  final String? detailTitle;
  final String? detailBody;
  final String? detailDateLabel;

  NotificationItem copyWith({
    String? id,
    NotificationCategory? category,
    String? title,
    String? description,
    DateTime? timestamp,
    bool? isRead,
    ReservationRecord? reservation,
    String? detailTitle,
    String? detailBody,
    String? detailDateLabel,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      reservation: reservation ?? this.reservation,
      detailTitle: detailTitle ?? this.detailTitle,
      detailBody: detailBody ?? this.detailBody,
      detailDateLabel: detailDateLabel ?? this.detailDateLabel,
    );
  }

  String get relativeTimestamp {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} minutes ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';

    final today = _dateOnly(now);
    final itemDate = _dateOnly(timestamp);
    if (today.difference(itemDate).inDays == 1) {
      return 'Yesterday';
    }
    if (today.difference(itemDate).inDays < 7) {
      return '${today.difference(itemDate).inDays} days ago';
    }
    return _formatMonthDay(timestamp);
  }

  DateTime get dayKey => _dateOnly(timestamp);

  String get groupLabel {
    final now = _dateOnly(DateTime.now());
    final diffDays = now.difference(dayKey).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    return 'Earlier';
  }

  IconData get icon {
    switch (category) {
      case NotificationCategory.reservationSubmitted:
      case NotificationCategory.reservationApproved:
      case NotificationCategory.reservationRejected:
      case NotificationCategory.reservationCancelled:
      case NotificationCategory.reservationReminder:
        return Icons.event_note_rounded;
      case NotificationCategory.announcement:
        return Icons.campaign_rounded;
      case NotificationCategory.roomMaintenance:
        return Icons.build_circle_rounded;
      case NotificationCategory.systemUpdate:
        return Icons.system_update_alt_rounded;
    }
  }

  Color get accentColor {
    switch (category) {
      case NotificationCategory.reservationSubmitted:
      case NotificationCategory.reservationReminder:
        return const Color(0xFFF6C914);
      case NotificationCategory.reservationApproved:
        return const Color(0xFF35B556);
      case NotificationCategory.reservationRejected:
      case NotificationCategory.reservationCancelled:
        return const Color(0xFFE53935);
      case NotificationCategory.announcement:
        return const Color(0xFF4053A7);
      case NotificationCategory.roomMaintenance:
        return const Color(0xFF35489A);
      case NotificationCategory.systemUpdate:
        return const Color(0xFF5A9E33);
    }
  }

  String get detailHeaderTitle {
    switch (category) {
      case NotificationCategory.reservationSubmitted:
      case NotificationCategory.reservationApproved:
      case NotificationCategory.reservationRejected:
      case NotificationCategory.reservationCancelled:
      case NotificationCategory.reservationReminder:
        return 'Reservation Details';
      case NotificationCategory.announcement:
      case NotificationCategory.roomMaintenance:
      case NotificationCategory.systemUpdate:
        return detailTitle ?? title;
    }
  }
}

class NotificationCenterStore {
  NotificationCenterStore._();

  static final ValueNotifier<List<NotificationItem>> _notifications =
      ValueNotifier<List<NotificationItem>>(_seedNotifications());

  static ValueNotifier<List<NotificationItem>> get listenable => _notifications;

  static bool get hasUnread => _notifications.value.any((item) => !item.isRead);

  static List<NotificationItem> get items => _notifications.value;

  static void addNotification(NotificationItem notification) {
    _notifications.value = <NotificationItem>[
      notification,
      ..._notifications.value.where((item) => item.id != notification.id),
    ]..sort((left, right) => right.timestamp.compareTo(left.timestamp));
  }

  static void addReservationSubmittedNotification(
    ReservationRecord reservation,
  ) {
    addNotification(
      NotificationItem(
        id: 'reservation-${reservation.id}-${DateTime.now().microsecondsSinceEpoch}',
        category: NotificationCategory.reservationSubmitted,
        title: 'Reservation Submitted',
        description:
            '${reservation.roomName} was submitted for ${reservation.reservationType.toLowerCase()}.',
        timestamp: DateTime.now(),
        reservation: reservation,
      ),
    );
  }

  static void markAllAsRead() {
    _notifications.value = _notifications.value
        .map((notification) => notification.copyWith(isRead: true))
        .toList();
  }

  static void markAsRead(String id) {
    _notifications.value = _notifications.value
        .map(
          (notification) => notification.id == id
              ? notification.copyWith(isRead: true)
              : notification,
        )
        .toList();
  }

  static void delete(String id) {
    _notifications.value = _notifications.value
        .where((notification) => notification.id != id)
        .toList();
  }

  static Future<void> refresh() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _notifications.value = List<NotificationItem>.from(_notifications.value)
      ..sort((left, right) => right.timestamp.compareTo(left.timestamp));
  }

  static List<NotificationItem> _seedNotifications() {
    final now = DateTime.now();
    return [
      NotificationItem(
        id: 'seed-1',
        category: NotificationCategory.reservationReminder,
        title: 'Reservation Reminder',
        description: 'Your reservation starts in 15 minutes.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        isRead: false,
      ),
      NotificationItem(
        id: 'seed-2',
        category: NotificationCategory.announcement,
        title: 'New Announcement',
        description: 'Room 618 scheduled maintenance has been posted.',
        timestamp: now.subtract(const Duration(hours: 4)),
        isRead: false,
        detailTitle: 'Room 618 Scheduled Maintenance',
        detailBody:
            'Please be advised that Room 618 will undergo scheduled maintenance on June 15, 2026, from 8:00 AM to 5:00 PM. The room will be temporarily unavailable for reservations during this period.',
      ),
      NotificationItem(
        id: 'seed-3',
        category: NotificationCategory.reservationApproved,
        title: 'Reservation Approved',
        description: 'Room 503 has been approved for your event.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        isRead: true,
      ),
      NotificationItem(
        id: 'seed-4',
        category: NotificationCategory.systemUpdate,
        title: 'System Update',
        description: 'NUtilize was updated with new reservation improvements.',
        timestamp: now.subtract(const Duration(days: 4)),
        isRead: true,
        detailTitle: 'System Update',
        detailBody:
            'NUtilize was updated to improve reservation tracking, notification handling, and overall reliability.',
      ),
    ]..sort((left, right) => right.timestamp.compareTo(left.timestamp));
  }
}
