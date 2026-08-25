import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
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
///
/// A persisted session can be stale after a restart, so a failed fetch refreshes
/// the CSRF once from the stored cookies before giving up.
final personalizedFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      ref.watch(
        webSessionControllerProvider.select((web) => (web.csrf, web.username)),
      );
      final controller = ArtworkFeedController((request) async {
        final dio = runtime.dio;
        if (dio == null) {
          throw const DAKitException(
            kind: DAKitFailureKind.configuration,
            code: 'app.runtime.dio',
            message: 'The network layer is not available.',
          );
        }
        var csrf = ref.read(webSessionControllerProvider).csrf;
        var cookieHeader = await webSession.cookieHeader();
        var page = await _tryFetchRfy(dio, csrf, cookieHeader, request);
        if (page == null) {
          // Stale session after a restart: re-read the CSRF from the persisted
          // cookies (headless page load) and retry once.
          await ref.read(webSessionRefresherProvider).refresh();
          csrf = ref.read(webSessionControllerProvider).csrf;
          cookieHeader = await webSession.cookieHeader();
          page = await _tryFetchRfy(dio, csrf, cookieHeader, request);
        }
        if (page == null) {
          throw const DAKitException(
            kind: DAKitFailureKind.authentication,
            code: 'web.session.unavailable',
            message: 'The personalized feed requires a signed-in web session.',
          );
        }
        ref.read(artworkStoreProvider.notifier).putAll(page.items);
        return page;
      });
      return controller;
    });

/// Fetches one rfy page, or `null` when the web session is missing or the
/// request failed (the caller then refreshes the session and retries).
Future<Page<Artwork>?> _tryFetchRfy(
  Dio dio,
  String csrf,
  String cookieHeader,
  PageRequest request,
) async {
  if (csrf.isEmpty || cookieHeader.isEmpty) return null;
  try {
    return await RfyFeedFetcher(dio).fetch(
      cookieHeader: cookieHeader,
      csrfToken: csrf,
      cursor: request.cursor,
    );
  } on Object {
    return null;
  }
}

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
      final controller = ArtworkFeedController(
        (request) {
          return OfficialDiscoveryRepository(runtime.transport!)
              .watched(request);
        },
        // A larger first page surfaces more distinct watched artists in the
        // top avatar strip instead of a few heavy posters dominating it.
        pageSize: 50,
      );
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
