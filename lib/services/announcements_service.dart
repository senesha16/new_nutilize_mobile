import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

/// Represents an announcement record from the announcements table.
class AnnouncementRecord {
  final int announcementId;
  final String title;
  final String body;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String? announcerName;

  AnnouncementRecord({
    required this.announcementId,
    required this.title,
    required this.body,
    required this.isActive,
    required this.createdAt,
    this.publishedAt,
    this.expiresAt,
    this.announcerName,
  });

  factory AnnouncementRecord.fromJson(Map<String, dynamic> json) {
    return AnnouncementRecord(
      announcementId: _asInt(json['announcement_id']),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: _parseTimestamp(json['created_at']),
      publishedAt: json['published_at'] != null
          ? _parseTimestamp(json['published_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? _parseTimestamp(json['expires_at'])
          : null,
      announcerName: json['announcer_name'] as String?,
    );
  }

  String get displayName => announcerName ?? 'NUtilize Admin';

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.isNegative || diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return 'Long time ago';
    }
  }

  String truncateBody(int maxLength) {
    if (body.length <= maxLength) {
      return body;
    }
    return '${body.substring(0, maxLength)}...';
  }
}

class AnnouncementsService extends ChangeNotifier {
  static final AnnouncementsService _instance =
      AnnouncementsService._internal();

  factory AnnouncementsService() {
    return _instance;
  }

  AnnouncementsService._internal();

  final List<AnnouncementRecord> _announcements = [];
  RealtimeChannel? _subscription;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _refreshTimer;
  bool _isFetching = false;
  bool _fetchAgain = false;
  bool _realtimeJoined = false;
  DateTime? _lastFetchAt;

  List<AnnouncementRecord> get announcements =>
      List.unmodifiable(_announcements);

  /// Fetch all active announcements from the database, sorted by created_at descending (latest first)
  Future<List<AnnouncementRecord>> fetchAnnouncements({
    bool force = false,
  }) async {
    _ensureLiveUpdates();

    if (Supabase.instance.client.auth.currentSession == null) {
      return _announcements;
    }

    final now = DateTime.now();
    if (!force &&
        _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < const Duration(seconds: 3)) {
      return _announcements;
    }

    if (_isFetching) {
      if (force) _fetchAgain = true;
      return _announcements;
    }

    _isFetching = true;
    _lastFetchAt = now;
    try {
      final client = Supabase.instance.client;

      final response = await client
          .from('announcements')
          .select(
            'announcement_id, title, body, is_active, created_at, '
            'published_at, announcer_name',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final next = <AnnouncementRecord>[];
      for (final item in response as List) {
        final record = AnnouncementRecord.fromJson(
          Map<String, dynamic>.from(item as Map),
        );
        if (!record.isActive) continue;
        if (record.expiresAt != null &&
            record.expiresAt!.isBefore(DateTime.now())) {
          continue;
        }
        next.add(record);
      }

      if (_sameAnnouncements(next)) {
        return _announcements;
      }

      _announcements
        ..clear()
        ..addAll(next);
      notifyListeners();
      return _announcements;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching announcements: $e');
      }
      return _announcements;
    } finally {
      _isFetching = false;
      if (_fetchAgain) {
        _fetchAgain = false;
        unawaited(fetchAnnouncements(force: true));
      }
    }
  }

  /// Subscribe to real-time announcements updates
  Future<void> subscribeToAnnouncements() async {
    _ensureLiveUpdates();
    try {
      final client = Supabase.instance.client;

      if (client.auth.currentSession == null || _subscription != null) {
        return;
      }

      final channel = client.channel('public:announcements');
      channel.on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: '*', schema: 'public', table: 'announcements'),
        (payload, [ref]) {
          unawaited(fetchAnnouncements(force: true));
        },
      );
      _subscription = channel;
      channel.subscribe((status, [error]) {
        if (status == 'SUBSCRIBED') {
          _realtimeJoined = true;
          unawaited(fetchAnnouncements(force: true));
          return;
        }
        if (status == 'CHANNEL_ERROR' ||
            status == 'TIMED_OUT' ||
            status == 'CLOSED') {
          _realtimeJoined = false;
          final failed = _subscription;
          _subscription = null;
          if (failed != null) {
            unawaited(client.removeChannel(failed));
          }
        }
      });
    } catch (e) {
      _subscription = null;
      _realtimeJoined = false;
      if (kDebugMode) {
        print('Error subscribing to announcements: $e');
      }
    }
  }

  void _ensureLiveUpdates() {
    _authSubscription ??= Supabase.instance.client.auth.onAuthStateChange
        .listen((state) {
      if (state.session == null) return;
      unawaited(fetchAnnouncements(force: true));
      unawaited(subscribeToAnnouncements());
    });

    _refreshTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      if (_subscription == null || !_realtimeJoined) {
        unawaited(subscribeToAnnouncements());
      }
      unawaited(fetchAnnouncements(force: true));
    });
  }

  bool _sameAnnouncements(List<AnnouncementRecord> next) {
    if (_announcements.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      final current = _announcements[i];
      final incoming = next[i];
      if (current.announcementId != incoming.announcementId ||
          current.title != incoming.title ||
          current.body != incoming.body ||
          current.isActive != incoming.isActive ||
          current.announcerName != incoming.announcerName ||
          current.publishedAt != incoming.publishedAt) {
        return false;
      }
    }
    return true;
  }

  /// Unsubscribe from real-time updates
  Future<void> unsubscribeFromAnnouncements() async {
    try {
      final channel = _subscription;
      _subscription = null;
      _realtimeJoined = false;
      if (channel != null) {
        await Supabase.instance.client.removeChannel(channel);
      }
      _refreshTimer?.cancel();
      _refreshTimer = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from announcements: $e');
      }
    }
  }

  /// Get top N announcements (for carousel on home page)
  List<AnnouncementRecord> getTopAnnouncements({int limit = 3}) {
    return _announcements.take(limit).toList();
  }

  /// Clear all cached announcements
  void clearCache() {
    _announcements.clear();
    notifyListeners();
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}

/// Announcement timestamps are stored without a timezone, in UTC.
DateTime _parseTimestamp(dynamic value) {
  if (value is DateTime) {
    return value.isUtc ? value.toLocal() : value;
  }
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return DateTime.now();
  final parsed = DateTime.parse(raw);
  if (parsed.isUtc || raw.endsWith('Z') || raw.contains('+')) {
    return parsed.toLocal();
  }
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toLocal();
}
