import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../core/l10n/app_strings.dart';
import '../features/artist/artist_screen.dart';
import '../features/artist/folder_screen.dart';
import '../features/artwork/artwork_detail_screen.dart';
import '../features/diagnostics/diagnostics_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/proxy_settings_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tag/tag_screen.dart';
import '../features/watching/watching_screen.dart';
import '../features/watched/watched_feed_screen.dart';
import '../features/web_login/web_login_screen.dart';
import 'app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authRevision = ValueNotifier<int>(0);
  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: authRevision,
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/web-login',
        builder: (context, state) => const WebLoginScreen(),
      ),
      GoRoute(
        path: '/artwork/:id',
        builder: (context, state) =>
            ArtworkDetailScreen(artworkId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/artist/:username',
        builder: (context, state) =>
            ArtistScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/artist/:username/folder/:folderId',
        builder: (context, state) {
          final s = strings(
            ProviderScope.containerOf(
              context,
              listen: false,
            ).read(appLanguageProvider),
          );
          return FolderScreen(
            username: state.pathParameters['username']!,
            folderId: state.pathParameters['folderId']!,
            folderName: state.uri.queryParameters['name'] ?? s.folder,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'proxy',
            builder: (context, state) => const ProxySettingsScreen(),
          ),
          GoRoute(
            path: 'diagnostics',
            builder: (context, state) => const DiagnosticsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/watching',
        builder: (context, state) => const WatchingScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/tag/:tag',
        builder: (context, state) =>
            TagScreen(tag: state.pathParameters['tag']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/watch',
                builder: (context, state) => const WatchedFeedScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/search',
                builder: (context, state) => const SearchScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/favourites',
                builder: (context, state) => const FavouritesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/downloads',
                builder: (context, state) => const DownloadsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      return authRedirect(auth.status, state.matchedLocation);
    },
  );

  ref.listen(authControllerProvider, (_, _) => authRevision.value++);
  ref.onDispose(authRevision.dispose);
  ref.onDispose(router.dispose);
  return router;
});

/// Keeps first-run authentication separate from authenticated feed loading.
/// Exposed as a pure function so this critical route policy is regression
/// tested without constructing a platform WebView.
String? authRedirect(AuthStatus status, String location) {
  if (status == AuthStatus.unknown) return '/splash';
  if (status == AuthStatus.signedIn && location == '/splash') return '/';
  // A first-run user should see the actual sign-in flow, never a home-feed
  // request or error state. Explicit logout still lands on public Home through
  // the general signed-out redirect below.
  if (status == AuthStatus.signedOut && location == '/splash') {
    return '/web-login';
  }
  // Home remains available after the user dismisses sign-in or logs out. The
  // watched tab also stays reachable so it can show its own prompt.
  if (status != AuthStatus.signedIn &&
      location != '/' &&
      location != '/watch' &&
      location != '/web-login') {
    return '/';
  }
  return null;
}
