import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/auth/webview_oauth_bridge.dart';
import '../../core/data/web_session.dart';
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
  static final Uri _forgotUri = Uri.parse(
    'https://www.deviantart.com/users/forgot?kind=password',
  );
  static final Uri _joinUri = Uri.parse('https://www.deviantart.com/join');

  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _launchSub;
  Uri? _pendingAuthUri;
  bool _loading = true;
  bool _closeAfterReport = false;
  int _reportSeq = 0;
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
    final seq = ++_reportSeq;
    try {
      final raw = await controller.evaluateJavascript(
        source: "JSON.stringify({csrf: window.__CSRF_TOKEN__ || ''})",
      );
      if (seq != _reportSeq) return; // a newer report superseded this one
      if (raw is! String || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final csrf = (data['csrf'] as String?) ?? '';
      // Pages without a session state (the OAuth callback) have no CSRF token;
      // skip them so they don't overwrite a good session.
      if (csrf.isEmpty) return;
      // Read the login identity from the long-lived `userinfo` cookie instead
      // of the page's __INITIAL_STATE__, which the login/authorize pages do
      // not populate reliably.
      final username = await const WebSession().webUsername();
      final isLoggedIn = username.isNotEmpty;
      debugPrint(
        '[web-session] csrf=${csrf.length} isLoggedIn=$isLoggedIn '
        'username=$username',
      );
      await ref
          .read(webSessionControllerProvider.notifier)
          .report(csrf: csrf, username: username);
      _maybeClose();
    } on Object {
      // Best effort; the page may not expose the state during navigation.
    }
  }

  void _maybeClose() {
    if (!_closeAfterReport || !mounted) return;
    _closeAfterReport = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  /// Shows sign-in help: the account model, that any email can register, and
  /// browser shortcuts for password reset and registration.
  void _showLoginHelp() {
    final s = strings(ref.read(appLanguageProvider));
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                s.loginHelpTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(s.loginHelpBody),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_reset),
                title: Text(s.forgotPassword),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(
                    launchUrl(_forgotUri, mode: LaunchMode.externalApplication),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_add_alt),
                title: Text(s.registerAccount),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(
                    launchUrl(_joinUri, mode: LaunchMode.externalApplication),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);

    // When OAuth finishes, close only after the deviantart home page reports
    // the real web session (onLoadStop + _reportWebSession). Closing on a fixed
    // timer could pop before the home page loads and leave the web session
    // recorded as signed-out.
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != AuthStatus.signedIn &&
          next.status == AuthStatus.signedIn &&
          mounted &&
          !_closeAfterReport) {
        _closeAfterReport = true;
        // Fallback: if the home page never reports (navigation stalls), close
        // after a generous timeout so the user isn't stuck.
        final navigator = Navigator.of(context);
        Future<void>.delayed(const Duration(seconds: 8), () {
          if (mounted && _closeAfterReport) {
            _closeAfterReport = false;
            navigator.pop();
          }
        });
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(s.webLogin),
        actions: <Widget>[
          IconButton(
            tooltip: s.loginHelpTooltip,
            onPressed: _showLoginHelp,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: s.done,
            onPressed: () => context.pop(),
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
              unawaited(
                controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(_homeUri.toString())),
                ),
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
            // Report from any deviantart.com page. A sequence counter makes
            // the latest page win, so an earlier anonymous page (login) cannot
            // overwrite a later signed-in page (home).
            final uri = url;
            if (uri != null && uri.host == 'www.deviantart.com') {
              unawaited(_reportWebSession());
            }
          },
          onProgressChanged: (controller, progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
        ),
      ),
    );
  }
}
