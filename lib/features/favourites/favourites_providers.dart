import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final currentFavouritesProvider =
    StateNotifierProvider.autoDispose<ArtworkFeedController, ArtworkFeedState>((
      ref,
    ) {
      // Rebuild the favourites feed whenever the signed-in account changes.
      ref.watch(sessionStateProvider.select((s) => s.account?.id));
      final controller = ArtworkFeedController((request) {
        final account = ref.read(sessionStateProvider).account;
        if (account == null) {
          throw Exception('Login required to view favourites.');
        }
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).favourites(account.username, request);
      });
      return controller;
    });
