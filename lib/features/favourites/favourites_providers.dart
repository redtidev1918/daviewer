import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final currentFavouritesProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      final controller = ArtworkFeedController((request) {
        final auth = ref.read(authControllerProvider);
        final account = auth.account;
        if (account == null) {
          throw Exception('Login required to view favourites.');
        }
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).favourites(account.username, request);
      });
      return controller;
    });
