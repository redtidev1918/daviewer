import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/auth/web_session_refresher.dart';
import '../../core/data/data_access.dart';
import '../../core/data/web_search.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../core/search/interest_store.dart';
import '../../core/search/search_history_store.dart';
import '../artwork/artwork_store.dart';
import '../favourites/favourites_providers.dart';
import '../home/home_providers.dart';

final searchFeedProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, query) {
      final controller = ArtworkFeedController((request) async {
        final runtime = ref.read(runtimeProvider);
        final dio = runtime.dio;
        if (dio == null) {
          throw const DAKitException(
            kind: DAKitFailureKind.configuration,
            code: 'app.runtime.dio',
            message: 'The network layer is not available.',
          );
        }
        // Real search results come from the website's private search endpoint
        // (the official API removed `browse/search`). Prefer it whenever the
        // embedded WebView has a web session; a stale session is refreshed once
        // like the rfy feed. The official `browse/home?q=` fallback keeps the
        // previous behavior when no web session exists.
        final webSession = ref.read(webSessionProvider);
        var csrf = ref.read(webSessionControllerProvider).csrf;
        var cookieHeader = await webSession.cookieHeader();
        var page = await _tryWebSearch(dio, query, csrf, cookieHeader, request);
        if (page == null) {
          await ref.read(webSessionRefresherProvider).refresh();
          csrf = ref.read(webSessionControllerProvider).csrf;
          cookieHeader = await webSession.cookieHeader();
          page = await _tryWebSearch(dio, query, csrf, cookieHeader, request);
        }
        if (page != null) {
          ref.read(artworkStoreProvider.notifier).putAll(page.items);
          return page;
        }
        return dataAccessFor(runtime).search(query, request);
      });
      return controller;
    });

/// Fetches one page of web search results, or `null` when the web session is
/// missing or the request failed (the caller then refreshes the session and
/// retries once, finally falling back to the official API).
Future<Page<Artwork>?> _tryWebSearch(
  Dio dio,
  String query,
  String csrf,
  String cookieHeader,
  PageRequest request,
) async {
  if (csrf.isEmpty || cookieHeader.isEmpty) return null;
  try {
    return await WebSearchFetcher(dio).fetch(
      query: query,
      cookieHeader: cookieHeader,
      csrfToken: csrf,
      cursor: request.cursor,
    );
  } on Object {
    return null;
  }
}

/// A single representative artwork for a tag, used as the tag's preview image
/// (Pixiv-style). Picks the most popular deviation of the tag so the preview
/// looks curated rather than arbitrary.
final tagPreviewProvider = FutureProvider.autoDispose.family<Artwork?, String>((
  ref,
  tag,
) async {
  final runtime = ref.watch(runtimeProvider);
  try {
    final page = await OfficialDiscoveryRepository(runtime.transport!)
        .tag(tag, const PageRequest(limit: 1), sort: BrowseSort.popular);
    return page.items.isEmpty ? null : page.items.first;
  } on Object {
    return null;
  }
});

/// Searches users by name (official `user/friends/search` endpoint).
final userSearchProvider = FutureProvider.autoDispose
    .family<List<UserProfile>, String>((ref, query) async {
      final runtime = ref.watch(runtimeProvider);
      return OfficialUserRepository(runtime.transport!).searchFriends(query);
    });

/// Personalized search tags derived from the user's interests, weighted:
/// favourites (explicit interest, 3) > watched artists (2) > everything the
/// user has viewed (persisted view interests + the in-memory artwork cache, 1).
/// The persisted view interests survive app restarts, so recommendations are
/// available even before the favourites/watch feeds have loaded.
final recommendedTagsProvider = FutureProvider<List<String>>((ref) async {
  final persisted = await InterestStore.load();
  final counts = <String, int>{};
  void addAll(Iterable<String> tags, int weight) {
    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      counts[normalized] = (counts[normalized] ?? 0) + weight;
    }
  }

  // Persisted view interests: weight 1 each (already counted per view).
  addAll(persisted.keys, 1);
  addAll(ref.watch(currentFavouritesProvider).items.expand((a) => a.tags), 3);
  addAll(ref.watch(followingFeedProvider).items.expand((a) => a.tags), 2);
  addAll(ref.watch(artworkStoreProvider).values.expand((a) => a.tags), 1);
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(10).map((e) => e.key).toList(growable: false);
});

/// Merges weighted tag sources and returns the top tags by score. Pure so it
/// can be unit-tested.
List<String> recommendedTagsFrom(Map<List<String>, int> weighted) {
  final counts = <String, int>{};
  weighted.forEach((tags, weight) {
    for (final tag in tags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      counts[normalized] = (counts[normalized] ?? 0) + weight;
    }
  });
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(10).map((e) => e.key).toList(growable: false);
}

/// The recent-search history, persisted via [SearchHistoryStore].
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryController, List<String>>(
      (ref) => SearchHistoryController(),
    );

final class SearchHistoryController extends StateNotifier<List<String>> {
  SearchHistoryController() : super(const <String>[]) {
    _load();
  }

  Future<void> _load() async => state = await SearchHistoryStore.load();

  Future<void> add(String query) async =>
      state = await SearchHistoryStore.add(query);

  Future<void> remove(String query) async =>
      state = await SearchHistoryStore.remove(query);

  Future<void> clear() async {
    await SearchHistoryStore.clear();
    state = const <String>[];
  }
}
