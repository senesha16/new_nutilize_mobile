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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationActivityStore.listenable.addListener(
      _handleNotificationStoreChange,
    );
    _currentIndex = widget.initialIndex;
    _scheduleRefresh();
    unawaited(_refreshReservations());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
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
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        unawaited(_refreshReservations());
      }
    });
  }

  Future<void> _refreshReservations() async {
    if (_isRefreshing) {
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return;
    }

    final userId = AuthService.currentUser?['user_id'] as int?;
    if (userId == null) {
      return;
    }

    _isRefreshing = true;
    try {
      final records = await ReservationService().getReservationRecordsForUser(
        userId,
      );
      if (!mounted) {
        return;
      }
      ReservationActivityStore.replaceAll(records);
      NotificationActivityStore.syncFromReservations(DateTime.now());
    } catch (_) {
      // Ignore refresh failures and keep the shell responsive.
    } finally {
      _isRefreshing = false;
    }
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
      _showNotificationSnackBar(latest);
    }

    _lastNotifications = List<NotificationRecord>.from(notifications);
  }

  void _showNotificationSnackBar(NotificationRecord notification) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        content: Text(notification.title),
        action: SnackBarAction(
          label: 'View',
          onPressed: () {
            messenger.hideCurrentSnackBar();
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const NotificationPage()));
          },
        ),
      ),
    );
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (_currentIndex == 0) {
          SystemNavigator.pop();
        } else {
          _selectTab(0);
        }
      },
      child: AppShellScope(
        currentIndex: _currentIndex,
        onTabSelected: _selectTab,
        child: Scaffold(
          backgroundColor: const Color(0xFFF3F5FB),
          body: SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                HomePage(),
                CalendarPage(),
                RequestPage(),
                ProfilePage(),
              ],
            ),
          ),
          bottomNavigationBar: AppBottomNav(
            selectedIndex: _currentIndex,
            onTap: _selectTab,
          ),
        ),
      ),
    );
  }
}
