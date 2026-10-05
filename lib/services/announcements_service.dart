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
      announcementId: json['announcement_id'] as int,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['created_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      announcerName: json['announcer_name'] as String?,
    );
  }

  String get displayName => announcerName ?? 'NUtilize Admin';

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 60) {
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
  Timer? _refreshTimer;
  bool _isFetching = false;
  DateTime? _lastFetchAt;

  List<AnnouncementRecord> get announcements =>
      List.unmodifiable(_announcements);

  /// Fetch all active announcements from the database, sorted by created_at descending (latest first)
  Future<List<AnnouncementRecord>> fetchAnnouncements({
    bool force = false,
  }) async {
    if (Supabase.instance.client.auth.currentSession == null) {
      return _announcements;
    }

    final now = DateTime.now();
    if (!force &&
        _lastFetchAt != null &&
        now.difference(_lastFetchAt!) < const Duration(seconds: 15)) {
      return _announcements;
    }

    if (_isFetching) {
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
            'published_at, expires_at, announcer_name',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      _announcements.clear();
      for (final item in response as List) {
        _announcements.add(
          AnnouncementRecord.fromJson(item as Map<String, dynamic>),
        );
      }

      notifyListeners();
      return _announcements;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching announcements: $e');
      }
      return _announcements;
    } finally {
      _isFetching = false;
    }
  }

  /// Subscribe to real-time announcements updates
  Future<void> subscribeToAnnouncements() async {
    try {
      final client = Supabase.instance.client;

      if (client.auth.currentSession == null) {
        return;
      }

      if (_subscription != null) {
        return;
      }

      // Unsubscribe from previous subscription if any
      if (_subscription != null) {
        await client.removeChannel(_subscription!);
      }

      _subscription = client.channel('announcements');
      _subscription!.on(
        RealtimeListenTypes.postgresChanges,
        ChannelFilter(event: '*', schema: 'public', table: 'announcements'),
        (payload, [ref]) async {
          // Refetch announcements when any change is detected
          await fetchAnnouncements(force: true);
        },
      );
      _subscription!.subscribe();
      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        fetchAnnouncements();
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to announcements: $e');
      }
    }
  }

  /// Unsubscribe from real-time updates
  Future<void> unsubscribeFromAnnouncements() async {
    try {
      if (_subscription != null) {
        await Supabase.instance.client.removeChannel(_subscription!);
        _subscription = null;
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
