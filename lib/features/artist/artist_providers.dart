import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final artistProfileProvider = FutureProvider.autoDispose
    .family<UserProfileDetails, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).profile(username);
    });

final artistGalleryProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, username) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).gallery(username, request);
      });
      return controller;
    });

final artistFavouritesProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, username) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).favourites(username, request);
      });
      return controller;
    });
