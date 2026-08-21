import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/webview_oauth_bridge.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';

/// Hosts the embedded DeviantArt WebView.
///
/// This screen owns the deviantart.com web session. It is opened to let the
/// user sign in on the web (for the personalized `rfy/deviations` home feed)
/// and also receives DAKit OAuth authorize URLs so an existing web session can
/// complete OAuth without re-entering credentials.
final class WebLoginScreen extends ConsumerStatefulWidget {
  const WebLoginScreen({super.key});

  @override
  ConsumerState<WebLoginScreen> createState() => _WebLoginScreenState();
}

final class _WebLoginScreenState extends ConsumerState<WebLoginScreen> {
  static final Uri _loginUri = Uri.parse(
    'https://www.deviantart.com/users/login',
  );
  static final Uri _homeUri = Uri.parse('https://www.deviantart.com/');

  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _launchSub;
  Uri? _pendingAuthUri;
  bool _loading = true;
  bool _closeScheduled = false;
  double _progress = 0;
  late final AuthController _authController;

  WebViewOAuthBridge? get _bridge =>
      ref.read(runtimeProvider).webViewOAuthBridge;

  @override
  void initState() {
    super.initState();
    _authController = ref.read(authControllerProvider.notifier);
    final bridge = _bridge;
    if (bridge != null) {
      _launchSub = bridge.launchRequests.listen(_loadAuthRequest);
    }
    // Single unified login: this screen hosts the WebView that establishes BOTH
    // the DeviantArt web session and the OAuth authorization. Any "login"
    // button just opens this screen; once the WebView is subscribed here, we
    // auto-start the OAuth authorize so it completes in this same WebView.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authControllerProvider);
      if (!auth.oauthSignedIn && !auth.isLoggingIn && mounted) {
        _authController.login();
      }
    });
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

  /// Reads the web session (CSRF + login state + username) from the WebView
  /// page and reports it to the auth controller. The page must be read here
  /// because a plain HTTP client is rejected by deviantart.com's bot filter.
  Future<void> _reportWebSession() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final raw = await controller.evaluateJavascript(
        source:
            "JSON.stringify({csrf: window.__CSRF_TOKEN__ || '', "
            "isLoggedIn: !!window.__INITIAL_STATE__?.['@@publicSession']?.isLoggedIn, "
            "username: window.__INITIAL_STATE__?.['@@publicSession']?.user?.username || ''})",
      );
      if (raw is! String || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      await _authController.updateWebSessionInfo(
        csrf: (data['csrf'] as String?) ?? '',
        isLoggedIn: (data['isLoggedIn'] as bool?) ?? false,
        username: (data['username'] as String?) ?? '',
      );
    } on Object {
      // Best effort; the page may not expose the state during navigation.
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);

    // When an OAuth login finishes, close this screen so the user lands back
    // on the (now signed-in) native home. The close is delayed so the WebView
    // has time to load the deviantart home page and report the web session
    // (CSRF + login state) via onLoadStop — popping immediately would read the
    // session from the `dakit://oauth/callback` page, which has no
    // `__INITIAL_STATE__` and would wrongly record the web session as logged
    // out.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != AuthStatus.signedIn &&
          next.status == AuthStatus.signedIn &&
          mounted &&
          !_closeScheduled) {
        _closeScheduled = true;
        final navigator = Navigator.of(context);
        Future<void>.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) navigator.pop();
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(s.webLogin),
        actions: <Widget>[
          IconButton(
            tooltip: s.done,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
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
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_loginUri.toString())),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            final pending = _pendingAuthUri;
            if (pending != null) {
              _pendingAuthUri = null;
              controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(pending.toString())),
              );
            }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri != null && uri.scheme == 'dakit' && uri.host == 'oauth') {
              _bridge?.addCallback(uri);
              // Navigate back to the deviantart home page; its onLoadStop then
              // reports the real web session (CSRF + login state). Do NOT read
              // the session here — the callback page has no __INITIAL_STATE__.
              controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(_homeUri.toString())),
              );
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onLoadStart: (controller, url) {
            if (mounted) setState(() => _loading = true);
          },
          onLoadStop: (controller, url) {
            if (mounted) setState(() => _loading = false);
            unawaited(_reportWebSession());
          },
          onProgressChanged: (controller, progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
        ),
      ),
    );
  }
}
