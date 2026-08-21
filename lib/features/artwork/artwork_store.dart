import 'package:dakit_core/dakit_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory cache of [Artwork] objects that have already been loaded by a
/// feed.
///
/// The web personalized feed (`rfy/deviations`) identifies deviations by a
/// numeric id (`1365198134`) that the official OAuth API cannot resolve
/// (`deviation/{id}` only accepts UUIDs). Feeds therefore stash their fully
/// mapped [Artwork] here and the detail screen renders straight from the cache
/// instead of round-tripping through an OAuth call that would 404.
final artworkStoreProvider =
    NotifierProvider<ArtworkStore, Map<String, Artwork>>(ArtworkStore.new);

final class ArtworkStore extends Notifier<Map<String, Artwork>> {
  static const int _maxEntries = 512;

  @override
  Map<String, Artwork> build() => <String, Artwork>{};

  Artwork? byId(String id) => state[id];

  void putAll(Iterable<Artwork> artworks) {
    var next = Map<String, Artwork>.of(state);
    for (final artwork in artworks) {
      if (artwork.id.isEmpty) continue;
      next[artwork.id] = artwork;
    }
    if (next.length > _maxEntries) {
      final entries = next.entries.toList(growable: false);
      next = Map<String, Artwork>.fromEntries(
        entries.skip(entries.length - _maxEntries),
      );
    }
    state = next;
  }
}
