import 'dart:async';

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

/// A paged artwork feed that loads its first page automatically when created
/// (so screens never sit on a spinner), then supports pull-to-refresh and
/// infinite scroll via [refresh] / [loadMore].
final class ArtworkFeedController extends StateNotifier<ArtworkFeedState> {
  ArtworkFeedController(this._fetch, {bool autoLoad = true})
    : super(const ArtworkFeedState(isLoading: true)) {
    if (autoLoad) {
      unawaited(refresh());
    }
  }

  final Future<Page<Artwork>> Function(PageRequest request) _fetch;

  Future<void> refresh() async {
    if (!mounted) return;
    state = const ArtworkFeedState(isLoading: true);
    try {
      final page = await _fetch(const PageRequest(limit: 24));
      if (!mounted) return;
      state = ArtworkFeedState(items: page.items, nextCursor: page.nextCursor);
    } catch (error) {
      if (!mounted) return;
      state = ArtworkFeedState(error: error);
    }
  }

  Future<void> loadMore() async {
    if (!mounted || state.isLoading || !state.hasMore) return;
    final cursor = state.nextCursor;
    state = ArtworkFeedState(
      items: state.items,
      nextCursor: state.nextCursor,
      isLoading: true,
    );
    try {
      final page = await _fetch(PageRequest(cursor: cursor, limit: 24));
      if (!mounted) return;
      state = ArtworkFeedState(
        items: <Artwork>[...state.items, ...page.items],
        nextCursor: page.nextCursor,
      );
    } catch (error) {
      if (!mounted) return;
      state = ArtworkFeedState(
        items: state.items,
        nextCursor: cursor,
        error: error,
      );
    }
  }

  /// Re-fetches the first page without clearing the current items, so the feed
  /// updates in place without a spinner flicker (e.g. when the app resumes).
  Future<void> refreshSilently() async {
    if (!mounted || state.isLoading) return;
    try {
      final page = await _fetch(const PageRequest(limit: 24));
      if (!mounted) return;
      state = ArtworkFeedState(items: page.items, nextCursor: page.nextCursor);
    } on Object {
      // Keep the current items when a silent refresh fails.
    }
  }
}
