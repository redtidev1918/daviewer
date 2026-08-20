import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/feed/artwork_feed_controller.dart';
import 'app_empty_state.dart';
import 'app_error_state.dart';
import 'artwork_card.dart';

final class ArtworkFeedGrid extends StatelessWidget {
  const ArtworkFeedGrid({
    required this.feed,
    required this.emptyMessage,
    this.onRefresh,
    this.onLoadMore,
    super.key,
  });

  final ArtworkFeedState feed;
  final String emptyMessage;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (feed.error != null && feed.items.isEmpty) {
      return AppErrorState(
        message: '${feed.error}',
        onRetry: onRefresh == null
            ? null
            : () {
                onRefresh?.call();
              },
      );
    }
    if (feed.items.isEmpty && feed.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (feed.items.isEmpty) {
      return AppEmptyState(message: emptyMessage);
    }

    final grid = GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: feed.items.length + (feed.isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= feed.items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final artwork = feed.items[index];
        return ArtworkCard(
          artwork: artwork,
          onTap: () => context.go('/artwork/${artwork.id}'),
        );
      },
    );

    final refreshable = onRefresh == null
        ? grid
        : RefreshIndicator(onRefresh: onRefresh!, child: grid);

    if (onLoadMore == null) return refreshable;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 400) {
          onLoadMore?.call();
        }
        return false;
      },
      child: refreshable,
    );
  }
}
