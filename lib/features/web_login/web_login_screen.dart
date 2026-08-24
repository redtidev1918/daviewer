import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/auth/webview_oauth_bridge.dart';
import '../../core/data/web_user_agent.dart';
import '../../core/diagnostics/app_logger.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/proxy_controller.dart' as app_proxy;
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
  bool _pageLoadFailed = false;
  bool _showBrowser = false;
  bool _preparingBrowser = false;
  bool _socialSignIn = false;
  bool _testingNetwork = false;
  String _networkStatus = '';
  WebViewEnvironment? _webViewEnvironment;
  int _webViewGeneration = 0;
  int? _popupWindowId;
  int _reportSeq = 0;
  double _progress = 0;
  late final AuthController _authController;
  app_proxy.ProxyController? _proxyController;

  WebViewOAuthBridge? get _bridge =>
      ref.read(runtimeProvider).webViewOAuthBridge;

  @override
  void initState() {
    super.initState();
    _authController = ref.read(authControllerProvider.notifier);
    _proxyController = ref.read(runtimeProvider).proxyController;
    _proxyController?.addListener(_onProxyChanged);
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
    _proxyController?.removeListener(_onProxyChanged);
    unawaited(_launchSub?.cancel());
    super.dispose();
  }

  void _onProxyChanged() {
    if (mounted) setState(() {});
  }

  void _loadAuthRequest(Uri uri) {
    final controller = _controller;
    if (controller == null) {
      _pendingAuthUri = uri;
      if (!_showBrowser && !_preparingBrowser) unawaited(_openBrowser());
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
      final username = await ref.read(webSessionProvider).webUsername();
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

  Future<String> _waitForCommittedUsername() async {
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 750),
      const Duration(milliseconds: 1500),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      final username = await ref.read(webSessionProvider).webUsername();
      if (username.isNotEmpty) return username;
    }
    return '';
  }

  void _retryPage() {
    _controller = null;
    setState(() {
      _showBrowser = false;
      _pageLoadFailed = false;
    });
    unawaited(_openBrowser(social: _socialSignIn));
  }

  Future<void> _openBrowser({bool social = false}) async {
    if (_preparingBrowser) return;
    setState(() {
      _preparingBrowser = true;
      _socialSignIn = social;
      _networkStatus = '';
    });
    final environment = await ref
        .read(runtimeProvider)
        .webViewProxyManager
        ?.prepare();
    if (!mounted) return;
    setState(() {
      _webViewEnvironment = environment;
      _preparingBrowser = false;
      _showBrowser = true;
      _loading = true;
      _webViewGeneration++;
    });
  }

  Future<void> _testNetwork() async {
    final proxy = ref.read(runtimeProvider).proxyController;
    if (proxy == null || _testingNetwork) return;
    final s = strings(ref.read(appLanguageProvider));
    setState(() {
      _testingNetwork = true;
      _networkStatus = s.testingConnection;
    });
    final result = await proxy.testConnection();
    if (!mounted) return;
    setState(() {
      _testingNetwork = false;
      _networkStatus = result.isSuccess
          ? s.proxyTestSucceeded(result.elapsed.inMilliseconds)
          : s.proxyTestFailed;
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
        leading: _showBrowser
            ? IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () {
                  if (_popupWindowId != null) {
                    setState(() => _popupWindowId = null);
                    return;
                  }
                  _controller = null;
                  setState(() => _showBrowser = false);
                },
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(_showBrowser ? s.webLogin : s.signInWelcomeTitle),
        actions: <Widget>[
          IconButton(
            tooltip: s.settings,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
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
        bottom: _showBrowser && _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: _progress > 0 && _progress < 1 ? _progress : null,
                ),
              )
            : null,
      ),
      body: !_showBrowser
          ? _buildOnboarding(context, s)
          : ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: Column(
                children: <Widget>[
                  if (_socialSignIn)
                    Material(
                      color: theme.colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.info_outline, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text(s.socialSignInHint)),
                          ],
                        ),
                      ),
                    ),
                  if (_pageLoadFailed)
                    Material(
                      color: theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                s.loginPageLoadFailed,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/settings/proxy'),
                              child: Text(s.proxy),
                            ),
                            TextButton(
                              onPressed: _retryPage,
                              child: Text(s.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        InAppWebView(
                          key: ValueKey<int>(_webViewGeneration),
                          webViewEnvironment: _webViewEnvironment,
                          initialUrlRequest: URLRequest(
                            url: WebUri(_loginUri.toString()),
                          ),
                          initialSettings: InAppWebViewSettings(
                            javaScriptEnabled: true,
                            javaScriptCanOpenWindowsAutomatically: true,
                            supportMultipleWindows: true,
                            thirdPartyCookiesEnabled: true,
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
                          onCreateWindow: (controller, action) async {
                            // DeviantArt opens Google/Apple login with window.open().
                            // Attach the native popup window to a second in-app WebView.
                            // This also handles providers that create about:blank first
                            // and navigate it later, which cannot be recovered by merely
                            // copying the initial request URL into the parent view.
                            if (!mounted) return false;
                            setState(() {
                              _popupWindowId = action.windowId;
                              _loading = true;
                              _pageLoadFailed = false;
                            });
                            return true;
                          },
                          onLoadStart: (controller, url) {
                            if (mounted) {
                              setState(() {
                                _loading = true;
                                _pageLoadFailed = false;
                              });
                            }
                          },
                          onLoadStop: (controller, url) {
                            if (mounted) setState(() => _loading = false);
                            // Report from any deviantart.com page. A sequence counter
                            // makes the latest page win, so an earlier anonymous page
                            // cannot overwrite a later signed-in page.
                            final uri = url;
                            if (uri != null &&
                                uri.host == 'www.deviantart.com') {
                              unawaited(_reportWebSession());
                            }
                          },
                          onReceivedHttpError:
                              (controller, request, response) async {
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
                                final username =
                                    await _waitForCommittedUsername();
                                if (!shouldRecoverLogin403(
                                      isMainFrame:
                                          request.isForMainFrame == true,
                                      statusCode: response.statusCode ?? 0,
                                      username: username,
                                    ) ||
                                    !mounted) {
                                  if (mounted) {
                                    setState(() => _pageLoadFailed = true);
                                  }
                                  AppLogger.instance.warning(
                                    'auth',
                                    'main-frame login returned HTTP 403 before a session '
                                        'cookie was committed',
                                  );
                                  return;
                                }
                                AppLogger.instance.warning(
                                  'auth',
                                  'recovering committed WebView login after HTTP 403',
                                );
                                _recoveringHttp403 = true;
                                await controller.loadUrl(
                                  urlRequest: URLRequest(
                                    url: WebUri(_homeUri.toString()),
                                  ),
                                );
                                _recoveringHttp403 = false;
                              },
                          onReceivedError: (controller, request, error) {
                            if (request.isForMainFrame != true || !mounted) {
                              return;
                            }
                            AppLogger.instance.warning(
                              'auth',
                              'login page network error: ${error.type} '
                                  '${error.description}',
                            );
                            setState(() {
                              _loading = false;
                              _pageLoadFailed = true;
                            });
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
                        if (_popupWindowId case final windowId?)
                          InAppWebView(
                            key: ValueKey<String>('popup-$windowId'),
                            windowId: windowId,
                            webViewEnvironment: _webViewEnvironment,
                            initialSettings: InAppWebViewSettings(
                              javaScriptEnabled: true,
                              javaScriptCanOpenWindowsAutomatically: true,
                              supportMultipleWindows: true,
                              thirdPartyCookiesEnabled: true,
                              userAgent: webUserAgent,
                              transparentBackground: false,
                            ),
                            shouldOverrideUrlLoading:
                                (popupController, navigationAction) async {
                                  final uri = navigationAction.request.url;
                                  if (uri != null &&
                                      uri.scheme == 'dakit' &&
                                      uri.host == 'oauth') {
                                    _bridge?.addCallback(uri);
                                    if (mounted) {
                                      setState(() => _popupWindowId = null);
                                    }
                                    unawaited(
                                      _controller?.loadUrl(
                                            urlRequest: URLRequest(
                                              url: WebUri(_homeUri.toString()),
                                            ),
                                          ) ??
                                          Future<void>.value(),
                                    );
                                    return NavigationActionPolicy.CANCEL;
                                  }
                                  return NavigationActionPolicy.ALLOW;
                                },
                            onLoadStop: (popupController, url) async {
                              if (mounted) setState(() => _loading = false);
                              final username = await ref
                                  .read(webSessionProvider)
                                  .webUsername();
                              if (username.isEmpty || !mounted) return;
                              setState(() => _popupWindowId = null);
                              await _controller?.loadUrl(
                                urlRequest: URLRequest(
                                  url: WebUri(_homeUri.toString()),
                                ),
                              );
                            },
                            onCloseWindow: (controller) {
                              if (mounted) {
                                setState(() => _popupWindowId = null);
                              }
                            },
                            onReceivedError: (controller, request, error) {
                              if (request.isForMainFrame != true || !mounted) {
                                return;
                              }
                              AppLogger.instance.warning(
                                'auth',
                                'social login popup network error: '
                                    '${error.type} ${error.description}',
                              );
                              setState(() {
                                _loading = false;
                                _pageLoadFailed = true;
                                _popupWindowId = null;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOnboarding(BuildContext context, AppStrings s) {
    final theme = Theme.of(context);
    final proxy = ref.watch(runtimeProvider).proxyController?.config;
    final currentProxy = proxy == null
        ? s.proxyCurrentDirect
        : s.proxyCurrentConfigured(proxy.toString());
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            children: <Widget>[
              Align(
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.palette_outlined,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                s.signInWelcomeTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                s.signInWelcomeBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _preparingBrowser ? null : () => _openBrowser(),
                icon: _preparingBrowser
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _preparingBrowser
                      ? s.openingOfficialLogin
                      : s.signInWithDeviantArt,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _preparingBrowser
                    ? null
                    : () => _openBrowser(social: true),
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(s.signInWithSocial),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(s.noAccountQuestion),
                  TextButton(
                    onPressed: () => launchUrl(
                      _joinUri,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(s.registerAccount),
                  ),
                  TextButton(
                    onPressed: () => launchUrl(
                      _forgotUri,
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Text(s.forgotPassword),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.lan_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.networkBeforeLogin,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.loginNetworkHint),
                      const SizedBox(height: 8),
                      Text(
                        currentProxy,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_networkStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_networkStatus, style: theme.textTheme.bodySmall),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          OutlinedButton.icon(
                            onPressed: () => context.push('/settings/proxy'),
                            icon: const Icon(Icons.settings_ethernet),
                            label: Text(s.proxy),
                          ),
                          OutlinedButton.icon(
                            onPressed: _testingNetwork ? null : _testNetwork,
                            icon: _testingNetwork
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.network_check),
                            label: Text(s.testConnection),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
