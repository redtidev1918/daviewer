import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/rfy_feed.dart';
import '../../core/data/web_session.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

/// Reads the DeviantArt web session (Cookie + CSRF) used by the home feed.
final webSessionProvider = Provider<WebSession>((ref) {
  final runtime = ref.watch(runtimeProvider);
  final dio = runtime.dio;
  if (dio == null) throw StateError('runtime.dio is not configured');
  return WebSession(dio);
});

/// The personalized home feed (`rfy/deviations`) rendered natively. It is
/// keyed by the signed-in account so switching accounts rebuilds the feed.
final rfyFeedProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      final fetcher = RfyFeedFetcher(runtime.dio!);
      final controller = ArtworkFeedController((request) async {
        final session = await webSession.read();
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

/// Daily deviations (official API, requires an OAuth session).
final dailyDeviationsProvider = FutureProvider.autoDispose<List<Artwork>>((
  ref,
) async {
  final runtime = ref.watch(runtimeProvider);
  return OfficialDiscoveryRepository(runtime.transport!).dailyDeviations();
});

/// The "deviations from artists you watch" feed (official API, OAuth session).
final followingFeedProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final runtime = ref.watch(runtimeProvider);
      final controller = ArtworkFeedController((request) {
        return OfficialDiscoveryRepository(runtime.transport!).watched(request);
      });
      return controller;
    });
