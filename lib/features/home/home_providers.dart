import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/auth/web_session_refresher.dart';
import '../../core/data/rfy_feed.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
import '../artwork/artwork_store.dart';

/// The website-personalized `rfy/deviations` recommendation feed, fetched with
/// the embedded WebView's web session (Cookie + CSRF). Requires a signed-in web
/// session and rebuilds when the web session identity changes.
final personalizedFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      ref.watch(
        webSessionControllerProvider.select((web) => (web.csrf, web.username)),
      );
      final controller = ArtworkFeedController((request) async {
        var csrf = ref.read(webSessionControllerProvider).csrf;
        if (csrf.isEmpty) {
          await ref.read(webSessionRefresherProvider).refresh();
          csrf = ref.read(webSessionControllerProvider).csrf;
        }
        final cookieHeader = await webSession.cookieHeader();
        final page = await RfyFeedFetcher(runtime.dio!).fetch(
          cookieHeader: cookieHeader,
          csrfToken: csrf,
          cursor: request.cursor,
        );
        ref.read(artworkStoreProvider.notifier).putAll(page.items);
        return page;
      });
      return controller;
    });

/// Daily deviations (official API, requires an OAuth session). Rebuilds when
/// the signed-in account changes. Kept alive so tab switches don't re-fetch.
final dailyDeviationsProvider = FutureProvider<List<Artwork>>((ref) async {
  ref.watch(
    authControllerProvider.select((auth) => (auth.status, auth.account?.id)),
  );
  final runtime = ref.watch(runtimeProvider);
  return OfficialDiscoveryRepository(runtime.transport!).dailyDeviations();
});

/// The "deviations from artists you watch" feed (official API, OAuth session).
/// Rebuilds when the signed-in account changes.
final followingFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final runtime = ref.watch(runtimeProvider);
      ref.watch(
        authControllerProvider.select(
          (auth) => (auth.status, auth.account?.id),
        ),
      );
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
