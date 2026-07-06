import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_nutilize_mobile/features/calendar/calendar_page.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/features/user/profile_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
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
