import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/data/rfy_feed.dart';
import '../../core/data/web_session.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

/// The personalized home feed (`rfy/deviations`) rendered natively. It rebuilds
/// whenever the web sign-in state changes.
final rfyFeedProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      ref.watch(sessionStateProvider.select((s) => s.webLoggedIn));
      final fetcher = RfyFeedFetcher(runtime.dio!);
      final controller = ArtworkFeedController((request) async {
        final session = await webSession.read();
        if (!session.isLoggedIn) {
          throw const WebLoginRequired();
        }
        final page = await fetcher.fetch(
          cookieHeader: session.cookieHeader,
          csrfToken: session.csrfToken,
          cursor: request.cursor,
        );
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
  ref.watch(sessionStateProvider.select((s) => s.account?.id));
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
      ref.watch(sessionStateProvider.select((s) => s.account?.id));
      final controller = ArtworkFeedController((request) {
        return OfficialDiscoveryRepository(runtime.transport!).watched(request);
      });
      return controller;
    });
