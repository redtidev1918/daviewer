import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/data/da_uri.dart';
import '../../core/data/web_session.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import 'home_feeds.dart';
import 'home_providers.dart';

/// Native home: two tabs, all rendered with the native feed UI.
///
/// - 推荐: the personalized `rfy/deviations` web feed (fetched natively with
///   the WebView's web session).
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
    final web = ref.watch(webSessionControllerProvider);
    final oauthSignedIn = auth.oauthSignedIn;
    final webLoggedIn = web.isLoggedIn;

    Widget? syncBanner;
    // Skip the sync banner while an OAuth authorization is in flight, so the
    // normal login flow doesn't flash a transient "web signed in, complete app
    // login" prompt before the account finishes loading.
    if (!auth.isLoggingIn && webLoggedIn == true && !oauthSignedIn) {
      syncBanner = LoginSyncBanner(
        message: s.webLoggedInOAuthMissing,
        actionLabel: s.login,
        closeLabel: s.close,
        onAction: () => context.push('/web-login'),
      );
    } else if (!auth.isLoggingIn && webLoggedIn == false && oauthSignedIn) {
      syncBanner = LoginSyncBanner(
        message: s.webLoggedOutOAuthActive,
        actionLabel: s.webLogin,
        closeLabel: s.close,
        onAction: () => context.push('/web-login'),
      );
    }

    return DefaultTabController(
      length: 2,
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
        body: Column(
          children: <Widget>[
            ?syncBanner,
            const Expanded(
              child: TabBarView(children: <Widget>[_RfyFeed(), DailyFeed()]),
            ),
          ],
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

final class _RfyFeed extends ConsumerStatefulWidget {
  const _RfyFeed();

  @override
  ConsumerState<_RfyFeed> createState() => _RfyFeedState();
}

final class _RfyFeedState extends ConsumerState<_RfyFeed>
    with WidgetsBindingObserver {
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
    // Refresh the personalized feed when the app comes back to the foreground
    // so it does not sit on a stale list indefinitely — silently, so the
    // current list stays visible while the new one loads.
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(rfyFeedProvider.notifier).refreshSilently();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final oauthSignedIn = ref.watch(authControllerProvider).oauthSignedIn;
    final web = ref.watch(webSessionControllerProvider);

    // Being signed out is a navigation state, not a failed recommendation
    // request. Do not even construct the auto-loading feed until both the web
    // identity and CSRF token are ready.
    if (!web.canLoadPersonalizedFeed) {
      return LoginPrompt(
        s: s,
        message: oauthSignedIn ? s.webSessionExpired : null,
        onLogin: () => context.push('/web-login'),
      );
    }

    final feed = ref.watch(rfyFeedProvider);
    final needLogin = feed.error is WebLoginRequired;

    if (needLogin) {
      // When OAuth is already signed in, the home feed only needs its web
      // session refreshed (the embedded WebView re-reads the CSRF/cookies);
      // when fully signed out, run the whole login flow.
      return LoginPrompt(
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
