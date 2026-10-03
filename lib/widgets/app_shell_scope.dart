import 'package:flutter/widgets.dart';

class AppShellScope extends InheritedWidget {
  static AppShellScope? _activeScope;

  const AppShellScope({
    super.key,
    required super.child,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

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

  static AppShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'AppShellScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return currentIndex != oldWidget.currentIndex ||
        onTabSelected != oldWidget.onTabSelected;
  }
}
