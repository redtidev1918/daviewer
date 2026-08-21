import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/session_state.dart';
import '../../core/data/rfy_feed.dart';
import '../../core/data/web_session.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
import '../artwork/artwork_store.dart';

/// The personalized home feed (`rfy/deviations`) rendered natively. It rebuilds
/// whenever the web sign-in state changes.
final rfyFeedProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      ref.watch(authControllerProvider.select((auth) => auth.webCsrf));
      final fetcher = RfyFeedFetcher(runtime.dio!);
      final controller = ArtworkFeedController((request) async {
        final auth = ref.read(authControllerProvider);
        final csrf = auth.webCsrf;
        // The home feed is personalized; only fetch when the web session is
        // actually signed in, otherwise prompt for login instead of showing
        // anonymous recommendations.
        if (csrf.isEmpty || auth.webLoggedIn != true) {
          throw const WebLoginRequired();
        }
        final cookieHeader = await webSession.cookieHeader();
        final RfyPage page;
        try {
          page = await fetcher.fetch(
            cookieHeader: cookieHeader,
            csrfToken: csrf,
            cursor: request.cursor,
          );
        } on DioException catch (error) {
          final status = error.response?.statusCode;
          // A stale/expired web session (e.g. a persisted CSRF that rotated)
          // returns 400 (`invalid_request`/`csrf`) or 401/403; surface a web
          // sign-in prompt rather than a raw home error.
          if (status == 400 || status == 401 || status == 403) {
            throw const WebLoginRequired();
          }
          rethrow;
        }
        // Cache the fully mapped artwork so the detail screen can render web
        // items (numeric ids) without an OAuth `deviation/{id}` lookup.
        ref.read(artworkStoreProvider.notifier).putAll(page.items);
        return Page<Artwork>(
          items: page.items,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
        );
      });
      return controller;
    });

/// Daily deviations (official API, requires an OAuth session). Rebuilds when
/// the signed-in account changes.
final dailyDeviationsProvider = FutureProvider.autoDispose<List<Artwork>>((
  ref,
) async {
  ref.watch(authControllerProvider.select((auth) => auth.account?.id));
  final runtime = ref.watch(runtimeProvider);
  return OfficialDiscoveryRepository(runtime.transport!).dailyDeviations();
});

/// The "deviations from artists you watch" feed (official API, OAuth session).
/// Rebuilds when the signed-in account changes.
final followingFeedProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final runtime = ref.watch(runtimeProvider);
      ref.watch(authControllerProvider.select((auth) => auth.account?.id));
      final controller = ArtworkFeedController((request) {
        return OfficialDiscoveryRepository(runtime.transport!).watched(request);
      });
      return controller;
    });
