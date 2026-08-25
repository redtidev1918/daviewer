import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/data/da_uri.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import 'home_feeds.dart';
import 'home_providers.dart';

/// Native home: two tabs, all rendered with the native feed UI.
///
/// - 推荐: the official OAuth `browse/home` discovery feed.
/// - 每日推荐: the official daily deviations (OAuth).
///
/// Deviations from watched artists live in the first-class "关注动态" tab
/// (see [WatchedFeedScreen]).
final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final auth = ref.watch(authControllerProvider);
    final oauthSignedIn = auth.oauthSignedIn;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.appTitle),
          actions: <Widget>[
            if (oauthSignedIn)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        foregroundImage: auth.account?.avatarUri == null
                            ? null
                            : CachedNetworkImageProvider(
                                auth.account!.avatarUri.toString(),
                              ),
                        child: const Icon(Icons.person, size: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(auth.account?.username ?? ''),
                    ],
                  ),
                ),
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
              tooltip: s.openLinkTooltip,
              onPressed: () => _showOpenLinkDialog(context, s),
              icon: const Icon(Icons.link),
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
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[_RecommendedFeed(), DailyFeed()],
        ),
      ),
    );
  }
}

Future<void> _showOpenLinkDialog(BuildContext context, AppStrings s) async {
  final controller = TextEditingController();
  final route = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(s.openLinkTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: s.openLinkHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            final link = parseDeviantArtUrl(controller.text);
            Navigator.of(context).pop(link?.route);
          },
          child: Text(s.open),
        ),
      ],
    ),
  );
  if (route != null && context.mounted) {
    unawaited(context.push(route));
  }
}

final class _RecommendedFeed extends ConsumerStatefulWidget {
  const _RecommendedFeed();

  @override
  ConsumerState<_RecommendedFeed> createState() => _RecommendedFeedState();
}

final class _RecommendedFeedState extends ConsumerState<_RecommendedFeed>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh discovery when the app comes back to the foreground so it does
    // not sit on a stale list indefinitely — silently, so the
    // current list stays visible while the new one loads.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(homeFeedProvider.notifier).refreshSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final s = strings(ref.watch(appLanguageProvider));
    if (!ref.watch(authControllerProvider).oauthSignedIn) {
      return LoginPrompt(s: s, onLogin: () => context.push('/web-login'));
    }
    final feed = ref.watch(homeFeedProvider);

    return ArtworkFeedGrid(
      feed: feed,
      emptyMessage: s.noArtworks,
      errorMessage: s.homeFeedLoadFailure,
      onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
      onLoadMore: () => ref.read(homeFeedProvider.notifier).loadMore(),
    );
  }
}
