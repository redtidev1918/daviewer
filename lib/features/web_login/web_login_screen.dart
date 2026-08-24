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
import '../../core/data/web_user_agent.dart';
import '../../core/diagnostics/app_logger.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';

bool shouldStartOAuthAfterWebSession({
  required bool webSignedIn,
  required bool oauthSignedIn,
  required bool oauthBusy,
  required bool alreadyRequested,
}) => webSignedIn && !oauthSignedIn && !oauthBusy && !alreadyRequested;

bool shouldRecoverLogin403({
  required bool isMainFrame,
  required int statusCode,
  required String username,
}) => isMainFrame && statusCode == 403 && username.isNotEmpty;

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
  static final Uri _contentSettingsUri = Uri.parse(
    'https://www.deviantart.com/settings/browsing',
  );

  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _launchSub;
  Uri? _pendingAuthUri;
  bool _loading = true;
  bool _closeAfterReport = false;
  bool _announcedWebLogin = false;
  bool _oauthRequested = false;
  bool _recoveringHttp403 = false;
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
    // OAuth is deliberately not started here. On a first install the login
    // form must finish establishing its cookies before the same WebView is
    // navigated to /oauth2/authorize; racing those two navigations produced a
    // misleading 403 after the user submitted a valid password on macOS.
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
      if (isLoggedIn && !_announcedWebLogin && mounted) {
        _announcedWebLogin = true;
        final s = strings(ref.read(appLanguageProvider));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.webLoginSuccess)));
      }
      if (isLoggedIn) _startOAuthIfNeeded();
      _maybeClose();
    } on Object {
      // Best effort; the page may not expose the state during navigation.
    }
  }

  void _startOAuthIfNeeded() {
    final auth = ref.read(authControllerProvider);
    if (!shouldStartOAuthAfterWebSession(
      webSignedIn: ref.read(webSessionControllerProvider).signedIn,
      oauthSignedIn: auth.oauthSignedIn,
      oauthBusy: auth.isLoggingIn,
      alreadyRequested: _oauthRequested,
    )) {
      return;
    }
    _oauthRequested = true;
    unawaited(
      _authController.login().whenComplete(() {
        _oauthRequested = false;
      }),
    );
  }

  void _maybeClose() {
    if (!_closeAfterReport || !mounted) return;
    _closeAfterReport = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leaveLogin();
    });
  }

  void _leaveLogin() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.visibility_outlined),
                title: Text(s.contentSettings),
                onTap: () {
                  Navigator.of(context).pop();
                  unawaited(
                    launchUrl(
                      _contentSettingsUri,
                      mode: LaunchMode.externalApplication,
                    ),
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
    final auth = ref.watch(authControllerProvider);

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
        final s = strings(ref.read(appLanguageProvider));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.loginSuccess)));
        // Fallback: if the home page never reports (navigation stalls), close
        // after a generous timeout so the user isn't stuck.
        Future<void>.delayed(const Duration(seconds: 8), () {
          if (mounted && _closeAfterReport) {
            _closeAfterReport = false;
            _leaveLogin();
          }
        });
      }
    });

    return Scaffold(
      // Keep the WebView full-size when the keyboard appears. Letting the
      // Scaffold shrink on viewInsets forces the embedded platform view to
      // resize in lockstep with the keyboard animation, which drops frames on
      // Android. With this off, the keyboard overlays the page and the web
      // form scrolls its focused field into view on its own.
      resizeToAvoidBottomInset: false,
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
            onPressed: _leaveLogin,
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
        child: Column(
          children: <Widget>[
            if (auth.error case final error?)
              Material(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          s.loginFailed(friendlyErrorMessage(error)),
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: auth.isLoggingIn
                            ? null
                            : _startOAuthIfNeeded,
                        child: Text(s.retry),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_loginUri.toString()),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  // A desktop Chrome UA makes deviantart.com serve its desktop
                  // login page, which includes the Google/Apple one-click
                  // sign-in buttons that the mobile layout omits.
                  userAgent: webUserAgent,
                  // Opaque: a transparent platform view uses a slower
                  // composition path and makes the keyboard animation heavier.
                  transparentBackground: false,
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
                  if (uri != null &&
                      uri.scheme == 'dakit' &&
                      uri.host == 'oauth') {
                    _bridge?.addCallback(uri);
                    // Navigate back to the deviantart home page; its
                    // onLoadStop then reports the real web session.
                    unawaited(
                      controller.loadUrl(
                        urlRequest: URLRequest(
                          url: WebUri(_homeUri.toString()),
                        ),
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
                  // Report from any deviantart.com page. A sequence counter
                  // makes the latest page win, so an earlier anonymous page
                  // cannot overwrite a later signed-in page.
                  final uri = url;
                  if (uri != null && uri.host == 'www.deviantart.com') {
                    unawaited(_reportWebSession());
                  }
                },
                onReceivedHttpError: (controller, request, response) async {
                  if (request.isForMainFrame != true ||
                      response.statusCode != 403 ||
                      _recoveringHttp403) {
                    return;
                  }
                  // DeviantArt can return a transient HTML 403 after accepting
                  // the first WebView password submission. If the persistent
                  // userinfo cookie was already committed, move to Home so a
                  // fresh CSRF can be read instead of leaving the user staring
                  // at the stale error document.
                  final username = await const WebSession().webUsername();
                  if (!shouldRecoverLogin403(
                        isMainFrame: request.isForMainFrame == true,
                        statusCode: response.statusCode ?? 0,
                        username: username,
                      ) ||
                      !mounted) {
                    return;
                  }
                  AppLogger.instance.warning(
                    'auth',
                    'recovering committed WebView login after HTTP 403',
                  );
                  _recoveringHttp403 = true;
                  await controller.loadUrl(
                    urlRequest: URLRequest(url: WebUri(_homeUri.toString())),
                  );
                  _recoveringHttp403 = false;
                },
                onProgressChanged: (controller, progress) {
                  // onProgressChanged fires continuously while loading; each
                  // setState rebuilds the whole Scaffold, so only rebuild on
                  // meaningful progress steps.
                  final value = progress / 100;
                  if (mounted && (value - _progress).abs() >= 0.02) {
                    setState(() => _progress = value);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
