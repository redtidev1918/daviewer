import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final currentFavouritesProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final controller = ArtworkFeedController((request) {
        final account = ref.read(authControllerProvider).account;
        if (account == null) {
          throw Exception('Login required to view favourites.');
        }
        final runtime = ref.read(runtimeProvider);
        final transport = runtime.transport;
        if (transport == null) {
          throw Exception('Pass DAKIT_CLIENT_ID at build time.');
        }
        return OfficialGalleryRepository(transport)
            .favourites(account.username, request);
      });
      ref.onDispose(controller.dispose);
      return controller;
    });
