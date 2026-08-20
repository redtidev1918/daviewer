import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final artistProfileProvider = FutureProvider.autoDispose
    .family<UserProfileDetails, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      return OfficialUserRepository(transport).profile(username);
    });

final artistGalleryProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, username) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        final transport = runtime.transport;
        if (transport == null) {
          throw Exception('Pass DAKIT_CLIENT_ID at build time.');
        }
        return OfficialGalleryRepository(transport).gallery(username, request);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });

final artistFavouritesProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, username) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        final transport = runtime.transport;
        if (transport == null) {
          throw Exception('Pass DAKIT_CLIENT_ID at build time.');
        }
        return OfficialGalleryRepository(transport)
            .favourites(username, request);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });
