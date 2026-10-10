import 'package:flutter/widgets.dart';

class AppShellScope extends InheritedWidget {
  static AppShellScope? _activeScope;

  const AppShellScope({
    super.key,
    required super.child,
    required this.currentIndex,
    required this.onTabSelected,
    this.onRefreshNotifications,
    this.shellRoute,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final Future<void> Function()? onRefreshNotifications;
  final ModalRoute<dynamic>? shellRoute;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>() ??
        _activeScope;
  }

  static void register(AppShellScope scope) {
    _activeScope = scope;
  }

  static void unregister(AppShellScope scope) {
    if (identical(_activeScope, scope)) {
      _activeScope = null;
    }
  }

  static bool selectTabFrom(BuildContext context, int index) {
    final scope = maybeOf(context);
    if (scope == null) return false;

    final route = scope.shellRoute;
    final navigator = Navigator.maybeOf(context, rootNavigator: true);
    if (route != null && navigator != null) {
      navigator.popUntil((candidate) => identical(candidate, route));
    }
    scope.onTabSelected(index);
    return true;
  }

  static AppShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppShellScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return currentIndex != oldWidget.currentIndex ||
        onTabSelected != oldWidget.onTabSelected ||
        onRefreshNotifications != oldWidget.onRefreshNotifications ||
        shellRoute != oldWidget.shellRoute;
  }
}
