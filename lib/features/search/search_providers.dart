import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

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
