import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feed/artwork_feed_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/artwork_feed_grid.dart';

/// The "browse by tag" feed (official `browse/tags` endpoint).
final tagFeedProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, tag) {
      final runtime = ref.watch(runtimeProvider);
      final controller = ArtworkFeedController((request) {
        return OfficialDiscoveryRepository(runtime.transport!).tag(tag, request);
      });
      return controller;
    });

final class TagScreen extends ConsumerWidget {
  const TagScreen({required this.tag, super.key});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(tagFeedProvider(tag));
    final s = strings(ref.watch(appLanguageProvider));
    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: ArtworkFeedGrid(
        feed: feed,
        emptyMessage: s.noArtworks,
        onRefresh: () => ref.read(tagFeedProvider(tag).notifier).refresh(),
        onLoadMore: () => ref.read(tagFeedProvider(tag).notifier).loadMore(),
      ),
    );
  }
}
