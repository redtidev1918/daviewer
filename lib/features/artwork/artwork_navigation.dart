import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'artwork_store.dart';

/// The immutable feed context carried by an artwork detail route.
///
/// Keeping the sequence on the route (instead of in one global mutable queue)
/// means opening a related work and then going back restores the original
/// gallery sequence correctly.
final class ArtworkBrowseSession {
  ArtworkBrowseSession(Iterable<String> ids)
    : ids = List<String>.unmodifiable(_deduplicate(ids));

  factory ArtworkBrowseSession.fromArtworks(Iterable<Artwork> artworks) =>
      ArtworkBrowseSession(artworks.map((artwork) => artwork.id));

  final List<String> ids;

  String? previousOf(String id) => _neighbor(id, -1);

  String? nextOf(String id) => _neighbor(id, 1);

  String? _neighbor(String id, int offset) {
    final index = ids.indexOf(id);
    if (index < 0) return null;
    final target = index + offset;
    if (target < 0 || target >= ids.length) return null;
    return ids[target];
  }

  static List<String> _deduplicate(Iterable<String> ids) {
    final seen = <String>{};
    return <String>[
      for (final id in ids)
        if (id.isNotEmpty && seen.add(id)) id,
    ];
  }
}

/// Opens a detail page with the visible feed as its previous/next sequence and
/// caches every item so numeric web IDs remain resolvable while swiping.
void openArtworkFromList(
  BuildContext context,
  WidgetRef ref, {
  required Iterable<Artwork> artworks,
  required Artwork artwork,
}) {
  final items = List<Artwork>.unmodifiable(artworks);
  ref.read(artworkStoreProvider.notifier).putAll(items);
  context.push(
    '/artwork/${artwork.id}',
    extra: ArtworkBrowseSession.fromArtworks(items),
  );
}

/// Converts a completed horizontal drag into feed navigation. A child
/// horizontal pager (multi-image artwork) wins the gesture arena; it delegates
/// only edge overscroll back to the artwork callbacks.
final class ArtworkSwipeRegion extends StatefulWidget {
  const ArtworkSwipeRegion({
    required this.child,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final Widget child;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<ArtworkSwipeRegion> createState() => _ArtworkSwipeRegionState();
}

final class _ArtworkSwipeRegionState extends State<ArtworkSwipeRegion> {
  double _distance = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.onPrevious == null && widget.onNext == null) {
      return widget.child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _distance = 0,
      onHorizontalDragUpdate: (details) => _distance += details.delta.dx,
      onHorizontalDragCancel: () => _distance = 0,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final threshold = (MediaQuery.sizeOf(context).width * 0.16).clamp(
          56.0,
          96.0,
        );
        if ((_distance > threshold || velocity > 700) &&
            widget.onPrevious != null) {
          widget.onPrevious!();
        } else if ((_distance < -threshold || velocity < -700) &&
            widget.onNext != null) {
          widget.onNext!();
        }
        _distance = 0;
      },
      child: widget.child,
    );
  }
}

enum ArtworkSwipeDirection { previous, next }

/// Accumulates only PageView edge overscroll. Moving among pages in a
/// multi-image work never changes artwork; another swipe beyond the first or
/// last page does.
final class ArtworkEdgeSwipeTracker {
  ArtworkSwipeDirection? _direction;
  double _distance = 0;

  void reset() {
    _direction = null;
    _distance = 0;
  }

  void add(double overscroll, {required bool atFirst, required bool atLast}) {
    final direction = switch (overscroll) {
      < 0 when atFirst => ArtworkSwipeDirection.previous,
      > 0 when atLast => ArtworkSwipeDirection.next,
      _ => null,
    };
    if (direction == null) return;
    if (_direction != direction) {
      _direction = direction;
      _distance = 0;
    }
    _distance += overscroll.abs();
  }

  ArtworkSwipeDirection? finish({double threshold = 56}) {
    final result = _distance >= threshold ? _direction : null;
    reset();
    return result;
  }
}
