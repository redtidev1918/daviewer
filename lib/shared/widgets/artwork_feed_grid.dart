import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../features/artwork/artwork_navigation.dart';
import 'app_empty_state.dart';
import 'app_error_state.dart';
import 'app_refresh_indicator.dart';
import 'artwork_card.dart';
import 'skeleton.dart';

final class ArtworkFeedGrid extends ConsumerWidget {
  const ArtworkFeedGrid({
    required this.feed,
    required this.emptyMessage,
    this.scrollController,
    this.onRefresh,
    this.onLoadMore,
    this.emptyActionLabel,
    this.emptyOnAction,
    this.errorMessage,
    super.key,
  });

  final ArtworkFeedState feed;
  final String emptyMessage;
  final ScrollController? scrollController;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onLoadMore;

  /// Optional call-to-action shown when the feed is empty (e.g. "Discover").
  final String? emptyActionLabel;
  final VoidCallback? emptyOnAction;

  /// Optional feature-specific copy that keeps provider/protocol failures out
  /// of the user interface. Raw errors remain available to the owning state
  /// and diagnostics.
  final String? errorMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body;

    if (feed.error != null && feed.items.isEmpty) {
      body = AppErrorState(
        message: errorMessage ?? friendlyErrorMessage(feed.error!),
        onRetry: onRefresh == null
            ? null
            : () {
                onRefresh?.call();
              },
      );
    } else if (feed.items.isEmpty && feed.isLoading) {
      body = const SkeletonGrid();
    } else if (feed.items.isEmpty) {
      body = AppEmptyState(
        message: emptyMessage,
        actionLabel: emptyActionLabel,
        onAction: emptyOnAction,
      );
    } else {
      // Masonry (waterfall) layout: cards render at their image's natural
      // aspect ratio, which looks more like a modern image feed.
      final width = MediaQuery.of(context).size.width;
      final crossAxisCount = (width / 200).round().clamp(2, 4);
      body = MasonryGridView.count(
        controller: scrollController,
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: feed.items.length + (feed.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feed.items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          final artwork = feed.items[index];
          return ArtworkCard(
            artwork: artwork,
            onTap: () => openArtworkFromList(
              context,
              ref,
              artworks: feed.items,
              artwork: artwork,
            ),
          );
        },
      );
    }

    // Wrap in a refreshable scroll view so pull-to-refresh works even when
    // the grid is empty or not yet filled.
    final refreshable = onRefresh == null
        ? body
        : AppRefreshIndicator(
            onRefresh: onRefresh!,
            child: body is ScrollView
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
