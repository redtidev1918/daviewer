import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';
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

/// Personalized search tags derived from the user's watched artists' recent
/// deviations. Empty when not signed in or when there is no watched content.
final recommendedTagsProvider = Provider<List<String>>((ref) {
  final items = ref.watch(followingFeedProvider).items;
  final counts = <String, int>{};
  for (final artwork in items) {
    for (final tag in artwork.tags) {
      final normalized = tag.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(10).map((e) => e.key).toList(growable: false);
});
