import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
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
