import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/artist/artist_screen.dart';
import '../features/artist/folder_screen.dart';
import '../features/artwork/artwork_detail_screen.dart';
import '../features/diagnostics/diagnostics_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/tag/tag_screen.dart';
import '../features/watching/watching_screen.dart';
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
        builder: (context, state) => FolderScreen(
          username: state.pathParameters['username']!,
          folderId: state.pathParameters['folderId']!,
          folderName: state.uri.queryParameters['name'] ?? '画集',
        ),
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
      final status = auth.status;
      final location = state.matchedLocation;
      if (status == AuthStatus.unknown) return '/splash';
      // Once signed in, always leave the splash for home.
      if (status == AuthStatus.signedIn && location == '/splash') {
        return '/';
      }
      // Home is the public landing page. Signed-out users (including right
      // after logout) land here — where the login buttons guide them —
      // instead of being dumped onto a full-screen login page.
      if (status != AuthStatus.signedIn &&
          location != '/' &&
          location != '/web-login') {
        return '/';
      }
      return null;
    },
  );

  ref.listen(authControllerProvider, (_, _) => authRevision.value++);
  ref.onDispose(authRevision.dispose);
  ref.onDispose(router.dispose);
  return router;
});
