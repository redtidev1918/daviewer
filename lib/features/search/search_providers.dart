import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final searchFeedProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, query) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        final transport = runtime.transport;
        if (transport == null) {
          throw Exception('Pass DAKIT_CLIENT_ID at build time.');
        }
        return OfficialArtworkRepository(transport).search(query, request);
      });
      return controller;
    });
