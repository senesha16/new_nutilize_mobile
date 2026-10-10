import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/notifications/notification_page.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/request.dart';
import 'package:new_nutilize_mobile/features/user/profile_page.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late int _currentIndex;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _hasSeenInitialNotifications = false;
  List<NotificationRecord> _lastNotifications = [];
  String? _lastShownNotificationId;
  OverlayEntry? _notificationOverlayEntry;
  RealtimeChannel? _approvalsChannel;
  RealtimeChannel? _reservationsChannel;
  AppShellScope? _registeredScope;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationActivityStore.listenable.addListener(
      _handleNotificationStoreChange,
    );
    _currentIndex = widget.initialIndex;
    _scheduleRefresh();
    _initRealtimeSubscriptions();
    unawaited(_loadReservationsForStartup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _dismissNotificationOverlay();
    _approvalsChannel?.unsubscribe();
    _reservationsChannel?.unsubscribe();
    final registeredScope = _registeredScope;
    if (registeredScope != null) {
      AppShellScope.unregister(registeredScope);
    }
    NotificationActivityStore.listenable.removeListener(
      _handleNotificationStoreChange,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshReservations());
    }
  }

  void _scheduleRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        unawaited(_refreshReservations());
      }
    });
  }

  Future<void> _loadReservationsForStartup() async {
    await _refreshReservations(includeDetails: false);
    if (!mounted || Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    await _refreshReservations();
  }

  Future<void> _refreshReservations({bool includeDetails = true}) async {
    if (_isRefreshing) {
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return;
    }

    _isRefreshing = true;
    try {
      final profile =
          AuthService.currentUser ?? await AuthService.restoreCurrentUser();
      final rawUserId = profile?['user_id'];
      final userId = rawUserId is int
          ? rawUserId
          : int.tryParse(rawUserId?.toString() ?? '');

      if (userId == null) {
        ReservationActivityStore.clear();
        return;
      }

      final records = await ReservationService().getReservationRecordsForUser(
        userId,
        includeDetails: includeDetails,
      );
      if (!mounted) {
        return;
      }
      final fetchedIds = records.map((record) => record.stableId).toSet();
      final locallyKnown = ReservationActivityStore.reservations
          .where((record) => !fetchedIds.contains(record.stableId))
          .toList();
      ReservationActivityStore.replaceAll([
        ...records,
        ...locallyKnown,
      ], syncNotifications: includeDetails);
      if (includeDetails) {
        NotificationActivityStore.syncFromReservations(DateTime.now());
      }
    } catch (_) {
      // Ignore refresh failures and keep the shell responsive.
    } finally {
      _isRefreshing = false;
    }
  }

  void _initRealtimeSubscriptions() {
    final client = Supabase.instance.client;

    _approvalsChannel = client.channel('public:reservation_approvals');
    _approvalsChannel?.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(
        event: '*',
        schema: 'public',
        table: 'reservation_approvals',
      ),
      (payload, [_]) {
        unawaited(_refreshReservations());
      },
    );
    _approvalsChannel?.subscribe();

    _reservationsChannel = client.channel('public:reservations');
    _reservationsChannel?.on(
      RealtimeListenTypes.postgresChanges,
      ChannelFilter(event: '*', schema: 'public', table: 'reservations'),
      (payload, [_]) {
        unawaited(_refreshReservations());
      },
    );
    _reservationsChannel?.subscribe();
  }

  void _handleNotificationStoreChange() {
    final notifications = NotificationActivityStore.notifications;

    if (!_hasSeenInitialNotifications) {
      _hasSeenInitialNotifications = true;
      _lastNotifications = List<NotificationRecord>.from(notifications);
      return;
    }

    final newIds = NotificationActivityStore.getNewNotificationIds(
      _lastNotifications,
      notifications,
    );

    if (newIds.isNotEmpty && mounted) {
      final latest = notifications.firstWhere(
        (notification) => newIds.contains(notification.id),
        orElse: () => notifications.first,
      );

      if (_lastShownNotificationId != latest.id) {
        _lastShownNotificationId = latest.id;
        _showNotificationSnackBar(latest);
      }
    }

    _lastNotifications = List<NotificationRecord>.from(notifications);
  }

  void _showNotificationSnackBar(NotificationRecord notification) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      return;
    }

    _lastShownNotificationId = null;
    _dismissNotificationOverlay();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopNotificationBanner(
        notification: notification,
        onDismiss: _dismissNotificationOverlay,
        onView: () {
          _dismissNotificationOverlay();
          _lastShownNotificationId = null;
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const NotificationPage()));
        },
      ),
    );
    _notificationOverlayEntry = entry;
    overlay.insert(entry);
  }

  void _dismissNotificationOverlay() {
    _notificationOverlayEntry?.remove();
    _notificationOverlayEntry = null;
  }

  void _selectTab(int index) {
    if (index == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final shellScope = AppShellScope(
      currentIndex: _currentIndex,
      onTabSelected: _selectTab,
      shellRoute: ModalRoute.of(context),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5FB),
        body: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: const [
              HomePage(),
              CalendarPage(),
              RequestPage(),
              ProfilePage(showBottomNavigation: false),
            ],
          ),
        ),
        bottomNavigationBar: AppBottomNav(
          selectedIndex: _currentIndex,
          onTap: _selectTab,
        ),
      ),
    );
    AppShellScope.register(shellScope);
    _registeredScope = shellScope;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (_currentIndex == 0) {
          SystemNavigator.pop();
        } else {
          _selectTab(0);
        }
      },
      child: shellScope,
    );
  }
}

class _TopNotificationBanner extends StatefulWidget {
  const _TopNotificationBanner({
    required this.notification,
    required this.onDismiss,
    required this.onView,
  });

  final NotificationRecord notification;
  final VoidCallback onDismiss;
  final VoidCallback onView;

  @override
  State<_TopNotificationBanner> createState() => _TopNotificationBannerState();
}

class _TopNotificationBannerState extends State<_TopNotificationBanner> {
  Timer? _dismissTimer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
      }
    });
    _dismissTimer = Timer(const Duration(seconds: 4), widget.onDismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 10,
      left: 16,
      right: 16,
      child: SafeArea(
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 9, 6, 9),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EDFF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: Color(0xFF35489A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF24304C),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onView,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFF6C914),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDismiss,
                      tooltip: 'Dismiss notification',
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF7A8199),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
