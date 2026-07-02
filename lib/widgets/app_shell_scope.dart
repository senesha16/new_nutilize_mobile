import 'package:flutter/widgets.dart';

class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required super.child,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
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
