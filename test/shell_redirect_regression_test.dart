import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Reproduces the first-run flow that leaves other pages blank after login:
/// splash -> redirect to a root login route -> login -> go('/') -> then
/// switching shell branches or pushing a top-level route.
void main() {
  testWidgets(
    'splash-redirect login, then go(/), keeps branches and pushes working',
    (tester) async {
      var signedIn = false;
      final router = GoRouter(
        initialLocation: '/splash',
        redirect: (context, state) {
          if (state.matchedLocation == '/splash') {
            return signedIn ? '/' : '/login';
          }
          return null;
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/splash',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('splash'))),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () {
                    signedIn = true;
                    context.go('/');
                  },
                  child: const Text('finish-login'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('settings-page')),
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
                  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
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
                          onPressed: () => context.push('/settings'),
                          child: const Text('home-open-settings'),
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
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Redirect sent us to the root login route.
      expect(find.text('finish-login'), findsOneWidget);

      // Finish login: go('/') from the root login route.
      await tester.tap(find.text('finish-login'));
      await tester.pumpAndSettle();
      expect(find.text('home-open-settings'), findsOneWidget);

      // Switch to the second branch.
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      expect(find.text('other-page'), findsOneWidget);

      // Back Home, then push a top-level route (settings).
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('home-open-settings'));
      await tester.pumpAndSettle();
      expect(find.text('settings-page'), findsOneWidget);
    },
  );
}
