import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Reproduces the reported bug: after pushing a top-level route (the login
/// WebView) from inside a shell branch and popping back, the bottom-navigation
/// branches stop responding. Verifies go_router 17.5's shell behavior for both
/// the push/pop path and the root-`go('/')` path.
void main() {
  Widget shellApp({required bool startAtLogin}) {
    final router = GoRouter(
      initialLocation: startAtLogin ? '/login' : '/',
      routes: <RouteBase>[
        GoRoute(
          path: '/login',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.go('/'),
                child: const Text('finish-login'),
              ),
            ),
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (index) => shell.goBranch(
                index,
                initialLocation: index == shell.currentIndex,
              ),
              destinations: const <NavigationDestination>[
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Other',
                ),
              ],
            ),
          ),
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/',
                  builder: (context, state) => Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () => context.push('/login'),
                        child: const Text('home-open-login'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: '/other',
                  builder: (context, state) => const Scaffold(
                    body: Center(child: Text('other-page')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('push/pop top-level route keeps shell branches working', (
    tester,
  ) async {
    await tester.pumpWidget(shellApp(startAtLogin: false));
    expect(find.text('home-open-login'), findsOneWidget);

    // Open the top-level login route, then close it (pop).
    await tester.tap(find.text('home-open-login'));
    await tester.pumpAndSettle();
    expect(find.text('finish-login'), findsOneWidget);
    // Simulate the login screen's pop (Navigator.pop like _closeScreen).
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.text('home-open-login'), findsOneWidget);

    // Switch to the second shell branch.
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.text('other-page'), findsOneWidget);
  });

  testWidgets('root go(/) into the shell keeps branches working', (
    tester,
  ) async {
    await tester.pumpWidget(shellApp(startAtLogin: true));
    expect(find.text('finish-login'), findsOneWidget);

    // Login screen is the root; close via context.go('/') like _closeScreen.
    await tester.tap(find.text('finish-login'));
    await tester.pumpAndSettle();
    expect(find.text('home-open-login'), findsOneWidget);

    // Switch to the second shell branch.
    await tester.tap(find.text('Other'));
    await tester.pumpAndSettle();
    expect(find.text('other-page'), findsOneWidget);
  });
}
