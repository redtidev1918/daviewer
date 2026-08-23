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
  final Set<String> _resolvedTagIds = <String>{};

  @override
  Map<String, Artwork> build() {
    _resolvedTagIds.clear();
    return <String, Artwork>{};
  }

  Artwork? byId(String id) => state[id];

  /// Whether the canonical detail endpoint has already confirmed this
  /// artwork's tags. This distinguishes a genuinely tagless work from a
  /// compact feed item whose `tags` field was omitted upstream.
  bool hasResolvedTags(String id) =>
      _resolvedTagIds.contains(id) || (state[id]?.tags.isNotEmpty ?? false);

  void putAll(Iterable<Artwork> artworks) {
    var next = Map<String, Artwork>.of(state);
    for (final artwork in artworks) {
      if (artwork.id.isEmpty) continue;
      final cached = next[artwork.id];
      // List endpoints are allowed to return sparse artwork objects. Never let
      // a later feed refresh erase tags that the canonical detail endpoint has
      // already hydrated.
      next[artwork.id] =
          cached != null && artwork.tags.isEmpty && cached.tags.isNotEmpty
          ? artwork.copyWith(tags: cached.tags)
          : artwork;
      if (artwork.tags.isNotEmpty) _resolvedTagIds.add(artwork.id);
    }
    if (next.length > _maxEntries) {
      final entries = next.entries.toList(growable: false);
      next = Map<String, Artwork>.fromEntries(
        entries.skip(entries.length - _maxEntries),
      );
      _resolvedTagIds.removeWhere((id) => !next.containsKey(id));
    }
    state = next;
  }

  /// Records the canonical tag result, including a confirmed empty list.
  void setTags(String id, List<String> tags) {
    final artwork = state[id];
    if (artwork == null) return;
    _resolvedTagIds.add(id);
    final normalized = List<String>.unmodifiable(tags);
    if (_sameStrings(artwork.tags, normalized)) return;
    state = <String, Artwork>{...state, id: artwork.copyWith(tags: normalized)};
  }

  /// Updates a cached artwork's favourite flag so the detail screen reflects a
  /// favourite/unfavourite action without a network round-trip.
  void setFavourite(String id, bool favourited) {
    final artwork = state[id];
    if (artwork == null) return;
    state = <String, Artwork>{
      ...state,
      id: artwork.copyWith(isFavourited: favourited),
    };
  }
}

bool _sameStrings(List<String> left, List<String> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
