import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/webview_oauth_bridge.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';

/// Home tab backed by the real DeviantArt home page.
///
/// The web home page uses DeviantArt's own `rfy/deviations` recommendation
/// engine (web-session based). Embedding the page gives the app exactly the
/// same personalized home feed as the web version.
///
/// This same WebView also owns the deviantart.com web-session cookies. When
/// the user starts native OAuth login, the bridge loads the OAuth authorize
/// URL here so an already logged-in web session can complete OAuth without
/// re-entering credentials.
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  static final Uri _homeUri = Uri.parse('https://www.deviantart.com/');

  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _launchSub;
  Uri? _pendingAuthUri;
  Uri _currentUri = _homeUri;
  bool _loading = true;
  Object? _error;
  double _progress = 0;
  bool _webCanGoBack = false;
  bool? _webLoggedIn;

  late final PullToRefreshController? _pullToRefreshController;

  WebViewOAuthBridge? get _bridge =>
      ref.read(runtimeProvider).webViewOAuthBridge;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _pullToRefreshController = _isMobile
        ? PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
              backgroundColor: Colors.grey.shade200,
              enabled: true,
              size: PullToRefreshSize.DEFAULT,
            ),
            onRefresh: () async {
              await _controller?.reload();
            },
          )
        : null;

    final bridge = _bridge;
    if (bridge != null) {
      _launchSub = bridge.launchRequests.listen(_loadAuthRequest);
    }
  }

  @override
  void dispose() {
    unawaited(_launchSub?.cancel());
    super.dispose();
  }

  void _loadAuthRequest(Uri uri) {
    final controller = _controller;
    if (controller == null) {
      _pendingAuthUri = uri;
      return;
    }
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  Future<void> _openInBrowser() async {
    // Only hand http(s) pages to the external browser; a transient non-web
    // URI (e.g. the OAuth callback) has no meaningful browser target.
    final target = _currentUri.isScheme('http') || _currentUri.isScheme('https')
        ? _currentUri
        : _homeUri;
    await launchUrl(target, mode: LaunchMode.externalApplication);
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await controller.reload();
  }

  Future<void> _updateWebState() async {
    final controller = _controller;
    if (controller == null) return;
    final canGoBack = await controller.canGoBack();
    var webLoggedIn = _webLoggedIn;
    try {
      final result = await controller.evaluateJavascript(
        source:
            "window.__INITIAL_STATE__?.['@@publicSession']?.isLoggedIn",
      );
      if (result is bool) webLoggedIn = result;
    } on Object {
      // The page may not expose the initial state during client-side
      // navigation; keep the previous value in that case.
    }
    if (!mounted) return;
    setState(() {
      _webCanGoBack = canGoBack;
      _webLoggedIn = webLoggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);
    final oauthSignedIn = auth.status == AuthStatus.signedIn;

    return PopScope(
      canPop: !_webCanGoBack,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final controller = _controller;
        if (controller == null) return;
        if (await controller.canGoBack()) {
          await controller.goBack();
          await _updateWebState();
          return;
        }
        if (!mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.home),
          actions: <Widget>[
            IconButton(
              tooltip: s.refresh,
              onPressed: _reload,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: s.openInBrowser,
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser),
            ),
            IconButton(
              tooltip: s.settings,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: _loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: _progress > 0 && _progress < 1 ? _progress : null,
                  ),
                )
              : null,
        ),
        body: Column(
          children: <Widget>[
            if (_webLoggedIn == true && !oauthSignedIn)
              _LoginSyncBanner(
                message: s.webLoggedInOAuthMissing,
                actionLabel: s.login,
                onAction: () =>
                    ref.read(authControllerProvider.notifier).login(),
              )
            else if (_webLoggedIn == false && oauthSignedIn)
              _LoginSyncBanner(
                message: s.webLoggedOutOAuthActive,
                actionLabel: s.webLogin,
                onAction: () {
                  _controller?.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(
                        'https://www.deviantart.com/users/login',
                      ),
                    ),
                  );
                },
              ),
            Expanded(
              child: Stack(
                children: <Widget>[
                  ColoredBox(
                    color: theme.scaffoldBackgroundColor,
                    child: InAppWebView(
                      initialUrlRequest: URLRequest(
                        url: WebUri(_homeUri.toString()),
                      ),
                      initialSettings: InAppWebViewSettings(
                        javaScriptEnabled: true,
                        transparentBackground: true,
                      ),
                      pullToRefreshController: _pullToRefreshController,
                      onWebViewCreated: (controller) {
                        _controller = controller;
                        final pending = _pendingAuthUri;
                        if (pending != null) {
                          _pendingAuthUri = null;
                          controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(pending.toString()),
                            ),
                          );
                        }
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        final uri = navigationAction.request.url;
                        if (uri != null &&
                            uri.scheme == 'dakit' &&
                            uri.host == 'oauth') {
                          _bridge?.addCallback(uri);
                          controller.loadUrl(
                            urlRequest: URLRequest(
                              url: WebUri(_homeUri.toString()),
                            ),
                          );
                          return NavigationActionPolicy.CANCEL;
                        }
                        return NavigationActionPolicy.ALLOW;
                      },
                      onLoadStart: (controller, url) {
                        if (!mounted) return;
                        setState(() {
                          _loading = true;
                          _error = null;
                          if (url != null) {
                            _currentUri = Uri.parse(url.toString());
                          }
                        });
                      },
                      onLoadStop: (controller, url) {
                        if (!mounted) return;
                        setState(() {
                          _loading = false;
                          _error = null;
                          if (url != null) {
                            _currentUri = Uri.parse(url.toString());
                          }
                        });
                        unawaited(_updateWebState());
                      },
                      onUpdateVisitedHistory: (controller, url, isReload) {
                        if (!mounted) return;
                        setState(() {
                          if (url != null) {
                            _currentUri = Uri.parse(url.toString());
                          }
                        });
                        unawaited(_updateWebState());
                      },
                      onProgressChanged: (controller, progress) {
                        if (!mounted) return;
                        setState(() {
                          _progress = progress / 100;
                        });
                      },
                      onReceivedError: (controller, request, error) {
                        if (!mounted) return;
                        setState(() {
                          _error = error.description;
                          _loading = false;
                        });
                      },
                    ),
                  ),
                  if (_error != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: theme.scaffoldBackgroundColor,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: 12),
                              Text('$_error', textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _reload,
                                child: Text(s.retry),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LoginSyncBanner extends StatelessWidget {
  const _LoginSyncBanner({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
