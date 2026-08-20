import 'package:dakit_core/dakit_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class ArtworkFeedState {
  const ArtworkFeedState({
    this.items = const <Artwork>[],
    this.nextCursor,
    this.isLoading = false,
    this.error,
  });

  final List<Artwork> items;
  final String? nextCursor;
  final bool isLoading;
  final Object? error;

  bool get hasMore => nextCursor != null;
}

final class ArtworkFeedController extends StateNotifier<ArtworkFeedState> {
  ArtworkFeedController(this._fetch)
    : super(const ArtworkFeedState(isLoading: true));

  final Future<Page<Artwork>> Function(PageRequest request) _fetch;

  Future<void> refresh() async {
    state = const ArtworkFeedState(isLoading: true);
    try {
      final page = await _fetch(const PageRequest(limit: 24));
      state = ArtworkFeedState(items: page.items, nextCursor: page.nextCursor);
    } catch (error) {
      state = ArtworkFeedState(error: error);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    final cursor = state.nextCursor;
    state = ArtworkFeedState(
      items: state.items,
      nextCursor: state.nextCursor,
      isLoading: true,
    );
    try {
      final page = await _fetch(PageRequest(cursor: cursor, limit: 24));
      state = ArtworkFeedState(
        items: <Artwork>[...state.items, ...page.items],
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      state = ArtworkFeedState(
        items: state.items,
        nextCursor: cursor,
        error: error,
      );
    }
  }
}
