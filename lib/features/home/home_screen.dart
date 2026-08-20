import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import '../../shared/widgets/artwork_card.dart';
import 'home_providers.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final s = strings(ref.watch(appLanguageProvider));
    final hasTransport =
        auth.status == AuthStatus.signedIn ||
        ref.watch(runtimeProvider).isConfigured;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: <Widget>[
            IconButton(
              tooltip: s.settings,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(text: s.home),
              Tab(text: s.daily),
              Tab(text: s.following),
            ],
          ),
        ),
        body: !hasTransport
            ? Center(child: Text(s.loginFirst))
            : const TabBarView(
                children: <Widget>[_HomeFeed(), _DailyFeed(), _FollowingFeed()],
              ),
      ),
    );
  }
}

final class _HomeFeed extends ConsumerWidget {
  const _HomeFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    final s = strings(ref.watch(appLanguageProvider));
    return ArtworkFeedGrid(
      feed: feed,
      emptyMessage: s.noArtworks,
      onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
      onLoadMore: () => ref.read(homeFeedProvider.notifier).loadMore(),
    );
  }
}

final class _DailyFeed extends ConsumerWidget {
  const _DailyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(dailyDeviationsProvider);
    final s = strings(ref.watch(appLanguageProvider));
    return daily.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => RefreshIndicator(
        onRefresh: () => ref.refresh(dailyDeviationsProvider.future),
        child: _ScrollableFill(
          child: AppErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(dailyDeviationsProvider),
          ),
        ),
      ),
      data: (items) => RefreshIndicator(
        onRefresh: () => ref.refresh(dailyDeviationsProvider.future),
        child: _ArtworkGrid(
          items: items,
          isLoading: false,
          error: null,
          emptyMessage: s.noDaily,
        ),
      ),
    );
  }
}

final class _FollowingFeed extends ConsumerWidget {
  const _FollowingFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final s = strings(ref.watch(appLanguageProvider));
    if (auth.status != AuthStatus.signedIn) {
      return Center(
        child: FilledButton(
          onPressed: () => context.push('/login'),
          child: Text(s.login),
        ),
      );
    }
    final feed = ref.watch(followingFeedProvider);
    return ArtworkFeedGrid(
      feed: feed,
      emptyMessage: s.noWatched,
      onRefresh: () => ref.read(followingFeedProvider.notifier).refresh(),
      onLoadMore: () => ref.read(followingFeedProvider.notifier).loadMore(),
    );
  }
}

/// Wraps a non-scrollable child in a scroll view so pull-to-refresh works
/// even for empty/error states.
final class _ScrollableFill extends StatelessWidget {
  const _ScrollableFill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: child,
        ),
      ),
    );
  }
}

final class _ArtworkGrid extends StatelessWidget {
  const _ArtworkGrid({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.emptyMessage,
  });

  final List<Artwork> items;
  final bool isLoading;
  final Object? error;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (error != null && items.isEmpty) {
      return _ScrollableFill(child: AppErrorState(message: '$error'));
    }
    if (items.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return _ScrollableFill(child: AppEmptyState(message: emptyMessage));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final artwork = items[index];
        return ArtworkCard(
          artwork: artwork,
          onTap: () => context.push('/artwork/${artwork.id}'),
        );
      },
    );
  }
}
