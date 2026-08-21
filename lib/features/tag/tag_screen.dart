import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

/// Related tag suggestions for a tag (official `browse/tags/search` autocomplete).
final relatedTagsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, tag) async {
      final runtime = ref.watch(runtimeProvider);
      final tags = await OfficialDiscoveryRepository(
        runtime.transport!,
      ).suggestTags(tag);
      // Exclude the tag itself and keep a short, readable list.
      return tags.where((t) => t.toLowerCase() != tag.toLowerCase()).take(12).toList();
    });

final class TagScreen extends ConsumerWidget {
  const TagScreen({required this.tag, super.key});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(tagFeedProvider(tag));
    final related = ref.watch(relatedTagsProvider(tag));
    final s = strings(ref.watch(appLanguageProvider));
    final isZh = ref.watch(appLanguageProvider) == AppLanguage.zh;
    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      body: Column(
        children: <Widget>[
          related.when(
            loading: () => const SizedBox.shrink(),
            error: (error, stackTrace) => const SizedBox.shrink(),
            data: (tags) => tags.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isZh ? '相关标签' : 'Related tags',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final t in tags)
                              ActionChip(
                                label: Text('#$t'),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => context.push(
                                  '/tag/${Uri.encodeComponent(t)}',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: ArtworkFeedGrid(
              feed: feed,
              emptyMessage: s.noArtworks,
              onRefresh: () => ref.read(tagFeedProvider(tag).notifier).refresh(),
              onLoadMore: () =>
                  ref.read(tagFeedProvider(tag).notifier).loadMore(),
            ),
          ),
        ],
      ),
    );
  }
}
