import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';
import 'artwork_detail_providers.dart';
import 'artwork_store.dart';

/// Favourites or unfavourites an artwork, resolving a numeric web id to its
/// OAuth UUID first. Updates the in-memory store so the detail screen reflects
/// the new state, and returns the new favourite flag.
Future<bool> setArtworkFavourite(
  WidgetRef ref,
  String artworkId,
  bool favourite,
) async {
  final runtime = ref.read(runtimeProvider);
  final social = OfficialSocialRepository(runtime.transport!);
  final uuid = await ref.read(artworkUuidProvider(artworkId).future);
  final result = favourite
      ? await social.favourite(uuid)
      : await social.unfavourite(uuid);
  ref
      .read(artworkStoreProvider.notifier)
      .setFavourite(artworkId, result.isFavourite);
  return result.isFavourite;
}
