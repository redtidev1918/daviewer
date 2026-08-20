import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/artist/artist_screen.dart';
import '../features/artwork/artwork_detail_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
import '../features/search/search_screen.dart';
import '../features/splash/splash_screen.dart';

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
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/artwork/:id',
        builder: (context, state) =>
            ArtworkDetailScreen(artworkId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/artist/:username',
        builder: (context, state) =>
            ArtistScreen(username: state.pathParameters['username']!),
      ),
      GoRoute(
        path: '/favourites',
        builder: (context, state) => const FavouritesScreen(),
      ),
      GoRoute(
        path: '/downloads',
        builder: (context, state) => const DownloadsScreen(),
      ),
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final status = auth.status;
      final location = state.matchedLocation;
      if (status == AuthStatus.unknown) return '/splash';
      if (status == AuthStatus.signedIn && location == '/login') return '/';
      if (status != AuthStatus.signedIn && location != '/login') {
        return '/login';
      }
      return null;
    },
  );

  ref.listen(authControllerProvider, (_, _) => authRevision.value++);
  ref.onDispose(authRevision.dispose);
  ref.onDispose(router.dispose);
  return router;
});
