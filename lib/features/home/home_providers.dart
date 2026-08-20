import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final homeFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        final transport = runtime.transport;
        if (transport == null) {
          throw Exception('Pass DAKIT_CLIENT_ID at build time.');
        }
        return OfficialArtworkRepository(transport).browse(request);
      });
      return controller;
    });

final dailyDeviationsProvider = FutureProvider.autoDispose<List<Artwork>>((
  ref,
) async {
  final runtime = ref.watch(runtimeProvider);
  final transport = runtime.transport;
  if (transport == null) {
    throw Exception('Pass DAKIT_CLIENT_ID at build time.');
  }
  return OfficialDiscoveryRepository(transport).dailyDeviations();
});

final followingFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        final transport = runtime.transport;
        if (transport == null) {
          throw Exception('Pass DAKIT_CLIENT_ID at build time.');
        }
        return OfficialDiscoveryRepository(transport).watched(request);
      });
      return controller;
    });
