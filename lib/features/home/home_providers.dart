import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/data_access.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

/// The signed-in account id (or null). Feeds watch this so their cached
/// state is rebuilt — instead of leaking into the next session — whenever the
/// user logs out or signs in as a different account.
final _accountIdProvider = Provider<String?>(
  (ref) => ref.watch(
    authControllerProvider.select((auth) => auth.account?.id),
  ),
);

final homeFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      // Reset cached pages when the signed-in account changes.
      ref.watch(_accountIdProvider);
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).browse(request);
      });
      return controller;
    });

final dailyDeviationsProvider = FutureProvider.autoDispose<List<Artwork>>((
  ref,
) async {
  ref.watch(_accountIdProvider);
  final runtime = ref.watch(runtimeProvider);
  return OfficialDiscoveryRepository(runtime.transport!).dailyDeviations();
});

final followingFeedProvider =
    StateNotifierProvider<ArtworkFeedController, ArtworkFeedState>((ref) {
      // Reset cached pages when the signed-in account changes.
      ref.watch(_accountIdProvider);
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return OfficialDiscoveryRepository(runtime.transport!).watched(request);
      });
      return controller;
    });
