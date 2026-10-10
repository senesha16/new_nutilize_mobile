import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

void main() {
  testWidgets('bottom navigation returns to the shell and selects each tab', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _NavigationHarness()));
    await tester.pumpAndSettle();

    const tabs = ['Home', 'Calendar', 'Request', 'User'];
    for (var index = 0; index < tabs.length; index++) {
      await tester.tap(find.text('Open pushed page'));
      await tester.pumpAndSettle();
      expect(find.text('Pushed page'), findsOneWidget);

      await tester.tap(find.text(tabs[index]));
      await tester.pumpAndSettle();

      expect(find.text('Tab $index'), findsOneWidget);
      expect(find.text('Pushed page'), findsNothing);
    }
  });
}

class _NavigationHarness extends StatefulWidget {
  const _NavigationHarness();

  @override
  State<_NavigationHarness> createState() => _NavigationHarnessState();
}

class _NavigationHarnessState extends State<_NavigationHarness> {
  int _selectedIndex = 0;
  AppShellScope? _registeredScope;

  @override
  Widget build(BuildContext context) {
    final scope = AppShellScope(
      currentIndex: _selectedIndex,
      onTabSelected: (index) => setState(() => _selectedIndex = index),
      shellRoute: ModalRoute.of(context),
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tab $_selectedIndex'),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const _PushedPage()),
                ),
                child: const Text('Open pushed page'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNav(),
      ),
    );
    AppShellScope.register(scope);
    _registeredScope = scope;
    return scope;
  }

  @override
  void dispose() {
    final scope = _registeredScope;
    if (scope != null) AppShellScope.unregister(scope);
    super.dispose();
  }
}

class _PushedPage extends StatelessWidget {
  const _PushedPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Pushed page')),
      bottomNavigationBar: AppBottomNav(),
    );
  }
}
