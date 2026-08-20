import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_state.dart';
import '../features/artwork/artwork_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/login/login_screen.dart';
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
    ],
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      if (auth.status == AuthStatus.unknown) return '/splash';
      return null;
    },
  );

  ref.listen(authControllerProvider, (_, _) => authRevision.value++);
  ref.onDispose(authRevision.dispose);
  ref.onDispose(router.dispose);
  return router;
});
