import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feed/artwork_feed_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import '../../shared/widgets/compact_tag_strip.dart';

/// The "browse by tag" feed (official `browse/tags` endpoint).
final tagFeedProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, tag) {
      final runtime = ref.watch(runtimeProvider);
      final controller = ArtworkFeedController((request) {
        return OfficialDiscoveryRepository(runtime.transport!)
            .tag(tag, request);
      });
      return controller;
    });

/// Related tag suggestions for a tag (official `browse/tags/search` autocomplete).
final relatedTagsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, tag) async {
      final runtime = ref.watch(runtimeProvider);
      final tags = await OfficialDiscoveryRepository(runtime.transport!)
          .suggestTags(tag);
      // Exclude the tag itself and keep a short, readable list.
      return tags
          .where((t) => t.toLowerCase() != tag.toLowerCase())
          .take(12)
          .toList();
    });

final class TagScreen extends ConsumerStatefulWidget {
  const TagScreen({required this.tag, super.key});

  final String tag;

  @override
  ConsumerState<TagScreen> createState() => _TagScreenState();
}

final class _TagScreenState extends ConsumerState<TagScreen> {
  bool _showRelated = true;
  double _lastPixels = 0;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical ||
        notification is! ScrollUpdateNotification) {
      return false;
    }
    final pixels = notification.metrics.pixels;
    final scrollingDown = pixels > _lastPixels;
    _lastPixels = pixels;
    final shouldShow = pixels < 16 || !scrollingDown;
    if (shouldShow != _showRelated && mounted) {
      setState(() => _showRelated = shouldShow);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(tagFeedProvider(widget.tag));
    final related = ref.watch(relatedTagsProvider(widget.tag));
    final s = strings(ref.watch(appLanguageProvider));
    return Scaffold(
      appBar: AppBar(title: Text('#${widget.tag}')),
      body: Column(
        children: <Widget>[
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: _showRelated
                ? related.when(
                    loading: () => const SizedBox.shrink(),
                    error: (error, stackTrace) => const SizedBox.shrink(),
                    data: (tags) => CompactTagStrip(
                      tags: tags,
                      leading: Text(
                        s.relatedTags,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      onSelected: (tag) =>
                          context.push('/tag/${Uri.encodeComponent(tag)}'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: ArtworkFeedGrid(
                feed: feed,
                emptyMessage: s.noArtworks,
                onRefresh: () =>
                    ref.read(tagFeedProvider(widget.tag).notifier).refresh(),
                onLoadMore: () =>
                    ref.read(tagFeedProvider(widget.tag).notifier).loadMore(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
