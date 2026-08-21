import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/data/da_uri.dart';
import '../../core/data/web_session.dart';
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
    final auth = ref.watch(authControllerProvider);
    final web = ref.watch(webSessionControllerProvider);
    final oauthSignedIn = auth.oauthSignedIn;
    final webLoggedIn = web.isLoggedIn;

    Widget? syncBanner;
    // Skip the sync banner while an OAuth authorization is in flight, so the
    // normal login flow doesn't flash a transient "web signed in, complete app
    // login" prompt before the account finishes loading.
    if (!auth.isLoggingIn && webLoggedIn == true && !oauthSignedIn) {
      syncBanner = _LoginSyncBanner(
        message: s.webLoggedInOAuthMissing,
        actionLabel: s.login,
        onAction: () => context.push('/web-login'),
      );
    } else if (!auth.isLoggingIn && webLoggedIn == false && oauthSignedIn) {
      syncBanner = _LoginSyncBanner(
        message: s.webLoggedOutOAuthActive,
        actionLabel: s.webLogin,
        onAction: () => context.push('/web-login'),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: <Widget>[
            if (oauthSignedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text(auth.account?.username ?? '')),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: FilledButton.tonal(
                    onPressed: () => context.push('/web-login'),
                    child: Text(s.login),
                  ),
                ),
              ),
            IconButton(
              tooltip: '打开链接',
              onPressed: () => _showOpenLinkDialog(context),
              icon: const Icon(Icons.link),
            ),
            IconButton(
              tooltip: s.notifications,
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_outlined),
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
        body: Column(
          children: <Widget>[
            ?syncBanner,
            const Expanded(
              child: TabBarView(
                children: <Widget>[_RfyFeed(), _DailyFeed(), _FollowingFeed()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showOpenLinkDialog(BuildContext context) async {
  final controller = TextEditingController();
  final route = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('打开 DeviantArt 链接'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '粘贴作品或作者链接，例如\nhttps://www.deviantart.com/xxx/art/xxx-123456789',
          border: OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final link = parseDeviantArtUrl(controller.text);
            Navigator.of(context).pop(link?.route);
          },
          child: const Text('打开'),
        ),
      ],
    ),
  );
  if (route != null && context.mounted) {
    context.push(route);
  }
}

final class _LoginSyncBanner extends StatefulWidget {
  const _LoginSyncBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  State<_LoginSyncBanner> createState() => _LoginSyncBannerState();
}

final class _LoginSyncBannerState extends State<_LoginSyncBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                widget.message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: widget.onAction,
              child: Text(widget.actionLabel),
            ),
            IconButton(
              tooltip: '关闭',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _dismissed = true),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
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
    final oauthSignedIn = ref
        .watch(authControllerProvider)
        .oauthSignedIn;
    final needLogin = feed.error is WebLoginRequired;

    if (needLogin) {
      // When OAuth is already signed in, the home feed only needs its web
      // session refreshed (the embedded WebView re-reads the CSRF/cookies);
      // when fully signed out, run the whole login flow.
      return _LoginPrompt(
        s: s,
        message: oauthSignedIn ? s.webSessionExpired : null,
        onLogin: () => context.push('/web-login'),
      );
    }

    return ArtworkFeedGrid(
      feed: feed,
      emptyMessage: s.noArtworks,
      onRefresh: () => ref.read(rfyFeedProvider.notifier).refresh(),
      onLoadMore: () => ref.read(rfyFeedProvider.notifier).loadMore(),
    );
  }
}

final class _DailyFeed extends ConsumerWidget {
  const _DailyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final s = strings(ref.watch(appLanguageProvider));
    if (!auth.oauthSignedIn) {
      return _LoginPrompt(
        s: s,
        onLogin: () => context.push('/web-login'),
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
    if (!auth.oauthSignedIn) {
      return _LoginPrompt(
        s: s,
        onLogin: () => context.push('/web-login'),
      );
    }
    final feed = ref.watch(followingFeedProvider);
    final isZh = ref.watch(appLanguageProvider) == AppLanguage.zh;
    return Column(
      children: <Widget>[
        // Keep the followed-users list adjacent to the followed artwork feed
        // so it is discoverable without digging into Settings.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => context.push('/watching'),
              icon: const Icon(Icons.people_outline, size: 18),
              label: Text(isZh ? '关注用户' : 'Watching'),
            ),
          ),
        ),
        Expanded(
          child: ArtworkFeedGrid(
            feed: feed,
            emptyMessage: s.noWatched,
            onRefresh: () => ref.read(followingFeedProvider.notifier).refresh(),
            onLoadMore: () =>
                ref.read(followingFeedProvider.notifier).loadMore(),
          ),
        ),
      ],
    );
  }
}

final class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.s, required this.onLogin, this.message});

  final AppStrings s;
  final VoidCallback onLogin;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.person_outline,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? s.loginFirst,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login),
              label: Text(s.login),
            ),
          ],
        ),
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
