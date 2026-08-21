import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/artwork_card.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import 'home_providers.dart';

/// Native home: three tabs, all rendered with the native feed UI.
///
/// - 首页: the personalized `rfy/deviations` web feed (fetched natively with
///   the WebView's web session).
/// - 每日推荐: the official daily deviations (OAuth).
/// - 关注: deviations from watched artists (OAuth).
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: <Widget>[
            IconButton(
              tooltip: s.webLogin,
              onPressed: () => context.push('/web-login'),
              icon: const Icon(Icons.language),
            ),
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
        body: const TabBarView(
          children: <Widget>[_RfyFeed(), _DailyFeed(), _FollowingFeed()],
        ),
      ),
    );
  }
}

final class _RfyFeed extends ConsumerWidget {
  const _RfyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(rfyFeedProvider);
    final s = strings(ref.watch(appLanguageProvider));

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => context.push('/web-login'),
              icon: const Icon(Icons.language, size: 18),
              label: Text(
                ref.watch(appLanguageProvider) == AppLanguage.zh
                    ? '登录网页版获得个性化推荐'
                    : 'Sign in on web for personalized feed',
              ),
            ),
          ),
        ),
        Expanded(
          child: ArtworkFeedGrid(
            feed: feed,
            emptyMessage: s.noArtworks,
            onRefresh: () => ref.read(rfyFeedProvider.notifier).refresh(),
            onLoadMore: () => ref.read(rfyFeedProvider.notifier).loadMore(),
          ),
        ),
      ],
    );
  }
}

final class _DailyFeed extends ConsumerWidget {
  const _DailyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final s = strings(ref.watch(appLanguageProvider));
    if (auth.status != AuthStatus.signedIn) {
      return _LoginPrompt(
        s: s,
        onLogin: () {
          context.push('/web-login');
          ref.read(authControllerProvider.notifier).login();
        },
      );
    }
    final daily = ref.watch(dailyDeviationsProvider);
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
      return _LoginPrompt(
        s: s,
        onLogin: () {
          context.push('/web-login');
          ref.read(authControllerProvider.notifier).login();
        },
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

final class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.s, required this.onLogin});

  final AppStrings s;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onLogin,
        icon: const Icon(Icons.login),
        label: Text(s.login),
      ),
    );
  }
}

/// Wraps a non-scrollable child in a scroll view so pull-to-refresh works even
/// for empty/error states.
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
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final artwork = items[index];
        return ArtworkCard(
          artwork: artwork,
          onTap: () => context.push('/artwork/${artwork.id}'),
        );
      },
    );
  }
}
