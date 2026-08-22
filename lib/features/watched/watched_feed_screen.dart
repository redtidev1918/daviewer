import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import '../home/home_feeds.dart';
import '../home/home_providers.dart';

/// The "deviations from artists you watch" feed — DeviantArt's
/// `/watch/deviations`. Surfaced as a first-class bottom tab (like a follow
/// feed) so new artwork from watched artists is one tap away, instead of
/// being buried as a third tab inside Home.
final class WatchedFeedScreen extends ConsumerWidget {
  const WatchedFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.following),
        actions: <Widget>[
          if (auth.oauthSignedIn)
            IconButton(
              tooltip: s.watching,
              onPressed: () => context.push('/watching'),
              icon: const Icon(Icons.people_outline),
            ),
        ],
      ),
      body: auth.oauthSignedIn
          ? const _WatchedGrid()
          : LoginPrompt(s: s, onLogin: () => context.push('/web-login')),
    );
  }
}

final class _WatchedGrid extends ConsumerWidget {
  const _WatchedGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final feed = ref.watch(followingFeedProvider);
    return ArtworkFeedGrid(
      feed: feed,
      emptyMessage: s.noWatched,
      onRefresh: () => ref.read(followingFeedProvider.notifier).refresh(),
      onLoadMore: () => ref.read(followingFeedProvider.notifier).loadMore(),
    );
  }
}
