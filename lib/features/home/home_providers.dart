import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/data/rfy_feed.dart';
import '../../core/data/web_session.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
import '../artwork/artwork_store.dart';

/// The personalized home feed (`rfy/deviations`) rendered natively. It rebuilds
/// whenever the web sign-in state changes. Kept alive (not autoDispose) so
/// switching Home tabs never re-fetches and flashes a skeleton again.
final rfyFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      final fetcher = RfyFeedFetcher(runtime.dio!);
      final controller = ArtworkFeedController((request) async {
        final web = ref.read(webSessionControllerProvider);
        final csrf = web.csrf;
        // The home feed is personalized; only fetch when the web session is
        // actually signed in, otherwise prompt for login instead of showing
        // anonymous recommendations.
        if (!web.canLoadPersonalizedFeed) {
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
      // When the cold-start headless refresh rotates the CSRF, re-fetch
      // SILENTLY (keep current items) instead of rebuilding the provider and
      // flashing a skeleton in front of the user.
      ref.listen<String>(
        webSessionControllerProvider.select((web) => web.csrf),
        (previous, next) {
          if (previous != null &&
              previous.isNotEmpty &&
              next.isNotEmpty &&
              previous != next) {
            controller.refreshSilently();
          }
        },
      );
      return controller;
    });

/// Daily deviations (official API, requires an OAuth session). Rebuilds when
/// the signed-in account changes. Kept alive so tab switches don't re-fetch.
final dailyDeviationsProvider = FutureProvider<List<Artwork>>((ref) async {
  ref.watch(authControllerProvider.select((auth) => auth.account?.id));
  final runtime = ref.watch(runtimeProvider);
  return OfficialDiscoveryRepository(runtime.transport!).dailyDeviations();
});

/// The "deviations from artists you watch" feed (official API, OAuth session).
/// Rebuilds when the signed-in account changes.
final followingFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final runtime = ref.watch(runtimeProvider);
      ref.watch(authControllerProvider.select((auth) => auth.account?.id));
      final controller = ArtworkFeedController((request) {
        return OfficialDiscoveryRepository(runtime.transport!).watched(request);
      });
      return controller;
    });

/// A watched artist plus the time of their most recent deviation in the feed.
final class WatchedAuthor {
  const WatchedAuthor({
    required this.username,
    required this.avatarUri,
    required this.lastUpdate,
  });

  final String username;
  final Uri? avatarUri;
  final DateTime? lastUpdate;
}

/// The watched artists that have posted in the current feed page, newest first.
/// Derived from [followingFeedProvider] so the avatar strip needs no extra
/// network round-trip.
final watchedAuthorsProvider = Provider<List<WatchedAuthor>>((ref) {
  return watchedAuthorsFrom(ref.watch(followingFeedProvider).items);
});

/// Groups a feed page by author (keeping each author's newest deviation) and
/// returns the authors newest-first. Pure so it can be unit-tested.
List<WatchedAuthor> watchedAuthorsFrom(List<Artwork> items) {
  final byAuthor = <String, WatchedAuthor>{};
  for (final artwork in items) {
    final username = artwork.author.username;
    if (username.isEmpty) continue;
    final current = byAuthor[username];
    final time = artwork.publishedAt;
    if (current == null ||
        (time != null &&
            (current.lastUpdate == null ||
                time.isAfter(current.lastUpdate!)))) {
      byAuthor[username] = WatchedAuthor(
        username: username,
        avatarUri: artwork.author.avatarUri,
        lastUpdate: time,
      );
    }
  }
  final list = byAuthor.values.toList()
    ..sort((a, b) => _newestFirst(a.lastUpdate, b.lastUpdate));
  return list;
}

int _newestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}
