import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../core/search/search_history_store.dart';
import '../artwork/artwork_store.dart';
import '../favourites/favourites_providers.dart';
import '../home/home_providers.dart';

final searchFeedProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, query) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).search(query, request);
      });
      return controller;
    });

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
/// favourites (explicit interest) > watched artists > everything the user has
/// browsed/seen (the in-memory artwork cache). Empty when nothing is available.
final recommendedTagsProvider = Provider<List<String>>((ref) {
  return recommendedTagsFrom(<List<String>, int>{
    ref
            .watch(currentFavouritesProvider)
            .items
            .expand((artwork) => artwork.tags)
            .toList(growable: false):
        3,
    ref
            .watch(followingFeedProvider)
            .items
            .expand((artwork) => artwork.tags)
            .toList(growable: false):
        2,
    ref
            .watch(artworkStoreProvider)
            .values
            .expand((artwork) => artwork.tags)
            .toList(growable: false):
        1,
  });
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
