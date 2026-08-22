import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/feed/artwork_feed_controller.dart';
import 'app_empty_state.dart';
import 'app_error_state.dart';
import 'artwork_card.dart';
import 'skeleton.dart';

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
    Widget body;

    if (feed.error != null && feed.items.isEmpty) {
      body = AppErrorState(
        message: friendlyErrorMessage(feed.error!),
        onRetry: onRefresh == null
            ? null
            : () {
                onRefresh?.call();
              },
      );
    } else if (feed.items.isEmpty && feed.isLoading) {
      body = const SkeletonGrid();
    } else if (feed.items.isEmpty) {
      body = AppEmptyState(message: emptyMessage);
    } else {
      body = GridView.builder(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: feed.items.length + (feed.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feed.items.length) {
            return const Center(child: CircularProgressIndicator());
          }
          final artwork = feed.items[index];
          return ArtworkCard(
            artwork: artwork,
            onTap: () => context.push('/artwork/${artwork.id}'),
          );
        },
      );
    }

    // Wrap in a refreshable scroll view so pull-to-refresh works even when
    // the grid is empty or not yet filled.
    final refreshable = onRefresh == null
        ? body
        : RefreshIndicator(
            onRefresh: onRefresh!,
            child: body is GridView
                ? body
                : LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight,
                        width: constraints.maxWidth,
                        child: body,
                      ),
                    ),
                  ),
          );

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
