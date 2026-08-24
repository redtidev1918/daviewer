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

bool shouldReplaceAbandonedOAuth({
  required bool authBusy,
  required bool requestedByThisScreen,
}) => authBusy && !requestedByThisScreen;

enum LoginHttpPageKind {
  ignored,
  humanVerification,
  committedSession,
  connectionFailure,
}

bool isPotentialHumanVerificationStatus(int statusCode) =>
    statusCode == 403 || statusCode == 429 || statusCode == 503;

/// Distinguishes an interactive anti-bot page from a real transport failure.
///
/// DeviantArt and its edge providers commonly return their human-verification
/// document with HTTP 403/429/503. The document is still usable inside the
/// WebView, so treating that response as a failed connection hides the very UI
/// the user needs to complete.
bool looksLikeHumanVerificationPage({
  Uri? pageUri,
  String title = '',
  String visibleText = '',
  bool hasChallengeElement = false,
}) {
  if (hasChallengeElement) return true;

  final uriText = pageUri?.toString().toLowerCase() ?? '';
  if (uriText.contains('/cdn-cgi/challenge-platform') ||
      uriText.contains('/_sec/cp_challenge') ||
      uriText.contains('px-captcha') ||
      uriText.contains('captcha') ||
      uriText.contains('challenge=')) {
    return true;
  }

  final text = '$title\n$visibleText'.toLowerCase();
  const markers = <String>[
    'verify you are human',
    'verify that you are human',
    'confirm you are human',
    'are you a human',
    'human verification',
    'not a robot',
    'press and hold',
    'checking your browser',
    'security verification',
    'complete the security check',
    'captcha',
    'recaptcha',
    'hcaptcha',
    'cloudflare ray id',
    '人机验证',
    '安全验证',
  ];
  return markers.any(text.contains);
}

LoginHttpPageKind classifyLoginHttpPage({
  required bool isMainFrame,
  required int statusCode,
  required String username,
  required bool isHumanVerification,
}) {
  if (!isMainFrame) return LoginHttpPageKind.ignored;
  if (isPotentialHumanVerificationStatus(statusCode) && isHumanVerification) {
    return LoginHttpPageKind.humanVerification;
  }
  if (statusCode != 403) return LoginHttpPageKind.ignored;
  return username.isNotEmpty
      ? LoginHttpPageKind.committedSession
      : LoginHttpPageKind.connectionFailure;
}

enum WebLoginMethod { deviantArt, google, apple }

bool shouldActivateLoginMethod({
  required WebLoginMethod method,
  required bool alreadyActivated,
  required Uri? pageUri,
}) {
  if (alreadyActivated ||
      pageUri == null ||
      pageUri.host != 'www.deviantart.com') {
    return false;
  }
  final isJoinPage = pageUri.path == '/join' || pageUri.path == '/join/oauth2';
  final isLoginPage = pageUri.path.startsWith('/users/login');
  return method == WebLoginMethod.deviantArt
      ? isJoinPage
      : isJoinPage || isLoginPage;
}

bool shouldResumeOAuthAfterSocialSignIn({
  required WebLoginMethod method,
  required bool oauthSignedIn,
  required bool callbackSeen,
  required Uri? mainFrameUri,
}) {
  if (method == WebLoginMethod.deviantArt || oauthSignedIn || callbackSeen) {
    return false;
  }
  if (mainFrameUri == null || mainFrameUri.scheme == 'about') return true;
  if (mainFrameUri.host != 'www.deviantart.com') return false;
  final path = mainFrameUri.path.toLowerCase();
  return path.startsWith('/users/login') ||
      path == '/join' ||
      path == '/join/oauth2' ||
      path == '/' ||
      path.isEmpty;
}

/// Hosts the embedded DeviantArt WebView.
///
/// This screen owns the deviantart.com web session and hosts DAKit's OAuth
/// authorize navigation. A first sign-in begins with one OAuth/PKCE request;
/// its password or social-provider page establishes the web cookies and then
/// returns to that same transaction for the App token exchange.
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
  bool _humanVerificationActive = false;
  bool _showBrowser = false;
  bool _preparingBrowser = false;
  WebLoginMethod _loginMethod = WebLoginMethod.deviantArt;
  bool _launchOAuthWhenReady = false;
  bool _loginMethodTriggered = false;
  bool _completingSocialSignIn = false;
  bool _socialCompletionFailed = false;
  bool _waitingForAuthorizationPage = false;
  bool _oauthCallbackSeen = false;
  bool _testingNetwork = false;
  bool? _networkReachable;
  String _networkStatus = '';
  WebViewEnvironment? _webViewEnvironment;
  int _webViewGeneration = 0;
  int? _popupWindowId;
  Uri? _activeAuthorizeUri;
  Uri? _lastMainFrameUri;
  int _reportSeq = 0;
  int _humanVerificationInspectionSeq = 0;
  Timer? _authorizationPageTimer;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_testNetwork());
    });
    // OAuth starts only after the user chooses a method. The authorize request
    // then owns the complete login round trip, so a social provider never has
    // to establish a web session and start a second authorization afterwards.
  }

  @override
  void dispose() {
    _authorizationPageTimer?.cancel();
    _proxyController?.removeListener(_onProxyChanged);
    unawaited(_launchSub?.cancel());
    final auth = ref.read(authControllerProvider);
    if (!auth.oauthSignedIn &&
        !_oauthCallbackSeen &&
        (_oauthRequested || auth.isLoggingIn)) {
      unawaited(_authController.cancelLogin());
    }
    super.dispose();
  }

  void _onProxyChanged() {
    if (mounted) setState(() {});
  }

  void _loadAuthRequest(Uri uri) {
    if (!mounted) return;
    _activeAuthorizeUri = uri;
    final controller = _controller;
    if (controller == null) {
      _pendingAuthUri = uri;
      if (!_showBrowser && !_preparingBrowser) unawaited(_openBrowser());
      return;
    }
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  void _armAuthorizationPageTimeout() {
    _authorizationPageTimer?.cancel();
    _authorizationPageTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_waitingForAuthorizationPage) return;
      AppLogger.instance.warning(
        'auth',
        'OAuth authorize URL did not reach the WebView within 20 seconds',
      );
      unawaited(_abortAuthorizationStartup());
    });
  }

  Future<void> _abortAuthorizationStartup() async {
    await _authController.cancelLogin();
    if (!mounted) return;
    _pendingAuthUri = null;
    _activeAuthorizeUri = null;
    setState(() {
      _oauthRequested = false;
      _launchOAuthWhenReady = false;
      _waitingForAuthorizationPage = false;
      _loading = false;
      _pageLoadFailed = true;
    });
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
      if (isLoggedIn &&
          ref.read(authControllerProvider).oauthSignedIn &&
          !_closeAfterReport) {
        _closeAfterReport = true;
      }
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
        if (mounted && _activeAuthorizeUri == null) {
          setState(() => _waitingForAuthorizationPage = false);
        }
      }),
    );
  }

  Future<void> _startUnifiedOAuth() async {
    var auth = ref.read(authControllerProvider);
    if (auth.oauthSignedIn || _oauthRequested) return;
    if (shouldReplaceAbandonedOAuth(
      authBusy: auth.isLoggingIn,
      requestedByThisScreen: _oauthRequested,
    )) {
      AppLogger.instance.warning(
        'auth',
        'replacing an abandoned OAuth transaction before opening login',
      );
      await _authController.cancelLogin();
      if (!mounted) return;
      auth = ref.read(authControllerProvider);
      if (auth.oauthSignedIn) return;
    }
    _oauthRequested = true;
    _armAuthorizationPageTimeout();
    unawaited(
      _authController.login().whenComplete(() {
        _authorizationPageTimer?.cancel();
        _oauthRequested = false;
        if (mounted && _activeAuthorizeUri == null) {
          setState(() => _waitingForAuthorizationPage = false);
        }
      }),
    );
  }

  void _maybeClose() {
    if (!_closeAfterReport || !mounted) return;
    _closeAfterReport = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_leaveLogin());
    });
  }

  Future<void> _leaveLogin() async {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.oauthSignedIn && (_oauthRequested || auth.isLoggingIn)) {
      await _authController.cancelLogin();
      if (!mounted) return;
    }
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
      const Duration(milliseconds: 2500),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      final username = await ref.read(webSessionProvider).webUsername();
      if (username.isNotEmpty) return username;
    }
    return '';
  }

  Future<void> _retryPage() async {
    _authorizationPageTimer?.cancel();
    _controller = null;
    await _authController.cancelLogin();
    if (!mounted) return;
    _pendingAuthUri = null;
    _activeAuthorizeUri = null;
    setState(() {
      _showBrowser = false;
      _pageLoadFailed = false;
    });
    await _openBrowser(method: _loginMethod);
  }

  Future<void> _closeBrowser() async {
    _authorizationPageTimer?.cancel();
    _controller = null;
    await _authController.cancelLogin();
    if (!mounted) return;
    _pendingAuthUri = null;
    _activeAuthorizeUri = null;
    setState(() {
      _showBrowser = false;
      _waitingForAuthorizationPage = false;
      _pageLoadFailed = false;
    });
  }

  Future<void> _openBrowser({
    WebLoginMethod method = WebLoginMethod.deviantArt,
  }) async {
    if (_preparingBrowser) return;
    final oauthSignedIn = ref.read(authControllerProvider).oauthSignedIn;
    setState(() {
      _preparingBrowser = true;
      _loginMethod = method;
      _launchOAuthWhenReady = !oauthSignedIn;
      _waitingForAuthorizationPage = !oauthSignedIn;
      _loginMethodTriggered = false;
      _completingSocialSignIn = false;
      _socialCompletionFailed = false;
      _oauthCallbackSeen = false;
      _activeAuthorizeUri = null;
      _lastMainFrameUri = null;
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

  String get _socialProviderName => switch (_loginMethod) {
    WebLoginMethod.google => 'Google',
    WebLoginMethod.apple => 'Apple',
    WebLoginMethod.deviantArt => 'DeviantArt',
  };

  Future<void> _triggerSelectedLoginMethod(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (!shouldActivateLoginMethod(
      method: _loginMethod,
      alreadyActivated: _loginMethodTriggered,
      pageUri: url == null ? null : Uri.tryParse(url.toString()),
    )) {
      return;
    }
    final provider = _socialProviderName;
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 600),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (!mounted || _loginMethodTriggered) return;
      try {
        final clicked = await controller.evaluateJavascript(
          source: _loginMethod == WebLoginMethod.deviantArt
              ? '''(() => {
                  const links = Array.from(document.querySelectorAll('a[href*="/users/login"]'));
                  const target = links.find((link) => (link.textContent || '').toLowerCase().includes('log in')) || links[0];
                  if (!target) return false;
                  target.click();
                  return true;
                })()'''
              : '''(() => {
                  const marker = document.querySelector('[aria-label="$provider"]');
                  if (!marker) return false;
                  const target = marker.closest('button, a, [role="button"]') || marker;
                  target.click();
                  return true;
                })()''',
        );
        if (clicked == true) {
          _loginMethodTriggered = true;
          AppLogger.instance.info(
            'auth',
            _loginMethod == WebLoginMethod.deviantArt
                ? 'opened the DeviantArt account form from the OAuth join page'
                : 'opened $provider from the official DeviantArt sign-in page',
          );
          return;
        }
      } on Object catch (error, stack) {
        AppLogger.instance.warning(
          'auth',
          'could not activate the selected sign-in control ($provider)',
          error,
          stack,
        );
      }
    }
  }

  Future<void> _finishSocialPopup(String reason) async {
    if (_loginMethod == WebLoginMethod.deviantArt || _completingSocialSignIn) {
      return;
    }
    if (mounted) {
      setState(() {
        _popupWindowId = null;
        _completingSocialSignIn = true;
        _socialCompletionFailed = false;
        _loading = true;
      });
    }
    AppLogger.instance.info(
      'auth',
      'social provider window finished ($reason); reconciling the same OAuth transaction',
    );

    final username = await _waitForCommittedUsername();
    if (!mounted) return;
    if (username.isEmpty) {
      setState(() {
        _completingSocialSignIn = false;
        _socialCompletionFailed = true;
        _loading = false;
        _pageLoadFailed = true;
      });
      AppLogger.instance.warning(
        'auth',
        'social provider window closed without a committed DeviantArt session',
      );
      return;
    }

    // Give the opener a short opportunity to continue by itself. If it is
    // still on the login document, reload the exact same PKCE authorize URI;
    // starting a new OAuth request here would lose the first transaction and
    // force the user through Google a second time.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    final authorizeUri = _activeAuthorizeUri;
    if (authorizeUri != null &&
        shouldResumeOAuthAfterSocialSignIn(
          method: _loginMethod,
          oauthSignedIn: auth.oauthSignedIn,
          callbackSeen: _oauthCallbackSeen,
          mainFrameUri: _lastMainFrameUri,
        )) {
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(authorizeUri.toString())),
      );
    }
    if (!mounted) return;
    setState(() => _completingSocialSignIn = false);
  }

  void _beginWebNavigation() {
    _humanVerificationInspectionSeq++;
    if (mounted && _humanVerificationActive) {
      setState(() => _humanVerificationActive = false);
    }
  }

  /// Returns `null` when this inspection was superseded by a newer navigation.
  Future<bool?> _inspectHumanVerification(
    InAppWebViewController controller, {
    WebUri? fallbackUri,
    bool clearOnNegative = false,
  }) async {
    // Multiple callbacks (HTTP error + load stop) may inspect the same
    // document concurrently. Only a real navigation invalidates them; one
    // callback must not cancel another callback that still owns HTTP error
    // classification for the same page.
    final inspectionSeq = _humanVerificationInspectionSeq;
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 750),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (!mounted || inspectionSeq != _humanVerificationInspectionSeq) {
        return null;
      }
      try {
        final raw = await controller.evaluateJavascript(
          source: r'''(() => {
            const challengeSelector = [
              'iframe[src*="captcha" i]',
              'iframe[src*="challenge" i]',
              '[id*="captcha" i]',
              '[class*="captcha" i]',
              '[id*="challenge-running" i]',
              '[class*="challenge-running" i]',
              'input[name*="captcha" i]',
              '#px-captcha',
              '.cf-challenge-running'
            ].join(',');
            const hasVisibleChallengeElement = Array.from(
              document.querySelectorAll(challengeSelector)
            ).some((element) => {
              const style = getComputedStyle(element);
              const rect = element.getBoundingClientRect();
              return style.display !== 'none' &&
                style.visibility !== 'hidden' &&
                Number(style.opacity || 1) !== 0 &&
                rect.width > 0 && rect.height > 0;
            });
            return JSON.stringify({
              url: location.href || '',
              title: document.title || '',
              text: (document.body && document.body.innerText || '').slice(0, 12000),
              hasChallengeElement: hasVisibleChallengeElement
            });
          })()''',
        );
        if (raw is String && raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final currentUri = Uri.tryParse('${decoded['url'] ?? ''}');
            final detected = looksLikeHumanVerificationPage(
              pageUri:
                  currentUri ??
                  (fallbackUri == null
                      ? null
                      : Uri.tryParse(fallbackUri.toString())),
              title: '${decoded['title'] ?? ''}',
              visibleText: '${decoded['text'] ?? ''}',
              hasChallengeElement: decoded['hasChallengeElement'] == true,
            );
            if (detected) {
              if (!mounted ||
                  inspectionSeq != _humanVerificationInspectionSeq) {
                return null;
              }
              setState(() {
                _humanVerificationActive = true;
                _pageLoadFailed = false;
                _socialCompletionFailed = false;
                _loading = false;
                _waitingForAuthorizationPage = false;
              });
              _authorizationPageTimer?.cancel();
              AppLogger.instance.info(
                'auth',
                'human-verification page detected; keeping the interactive '
                    'WebView visible',
              );
              return true;
            }
          }
        }
      } on Object catch (error, stack) {
        AppLogger.instance.debug(
          'auth',
          'could not inspect the current login document',
          error,
          stack,
        );
      }
    }
    if (!mounted || inspectionSeq != _humanVerificationInspectionSeq) {
      return null;
    }
    if (clearOnNegative && _humanVerificationActive) {
      setState(() => _humanVerificationActive = false);
    }
    return false;
  }

  Future<void> _handleSocialPopupError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceError error,
  ) async {
    if (request.isForMainFrame != true || !mounted) return;
    final challenge = await _inspectHumanVerification(
      controller,
      fallbackUri: request.url,
    );
    if (challenge != false || !mounted) return;
    final username = await ref.read(webSessionProvider).webUsername();
    if (!mounted) return;
    if (_humanVerificationActive) return;
    if (username.isNotEmpty) {
      await _finishSocialPopup('provider navigation completed');
      return;
    }
    AppLogger.instance.warning(
      'auth',
      'social login popup network error: ${error.type} ${error.description}',
    );
    setState(() {
      _loading = false;
      _pageLoadFailed = true;
      _socialCompletionFailed = false;
      _popupWindowId = null;
    });
  }

  Future<void> _handleSocialPopupHttpError(
    InAppWebViewController controller,
    WebResourceRequest request,
    WebResourceResponse response,
  ) async {
    final statusCode = response.statusCode ?? 0;
    if (request.isForMainFrame != true ||
        !isPotentialHumanVerificationStatus(statusCode) ||
        !mounted) {
      return;
    }
    final challenge = await _inspectHumanVerification(
      controller,
      fallbackUri: request.url,
    );
    if (challenge != false || !mounted) return;
    final username = await ref.read(webSessionProvider).webUsername();
    if (!mounted) return;
    if (_humanVerificationActive) return;
    if (username.isNotEmpty) {
      await _finishSocialPopup('provider HTTP response completed');
      return;
    }
    AppLogger.instance.warning(
      'auth',
      'social login popup returned HTTP $statusCode without a challenge page',
    );
    setState(() {
      _loading = false;
      _pageLoadFailed = true;
      _socialCompletionFailed = false;
      _popupWindowId = null;
    });
  }

  Future<void> _testNetwork() async {
    final proxy = ref.read(runtimeProvider).proxyController;
    if (proxy == null || _testingNetwork) return;
    final s = strings(ref.read(appLanguageProvider));
    setState(() {
      _testingNetwork = true;
      _networkReachable = null;
      _networkStatus = s.testingConnection;
    });
    final result = await proxy.testConnection();
    if (!mounted) return;
    final current = proxy.config;
    setState(() {
      _testingNetwork = false;
      _networkReachable = result.isSuccess;
      _networkStatus = result.isSuccess
          ? current == null
                ? s.directConnectionReady
                : s.proxyConnectionReady(current.toString())
          : s.connectionNeedsAttention;
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
            unawaited(_leaveLogin());
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
                  unawaited(_closeBrowser());
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
            onPressed: () => unawaited(_leaveLogin()),
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
                  if (_loginMethod != WebLoginMethod.deviantArt)
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
                            Expanded(
                              child: Text(
                                s.socialSignInHint(_socialProviderName),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_humanVerificationActive)
                    Material(
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.verified_user_outlined,
                              size: 20,
                              color: theme.colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.humanVerificationHint,
                                style: TextStyle(
                                  color: theme.colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ),
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
                                _socialCompletionFailed
                                    ? s.socialSignInIncomplete(
                                        _socialProviderName,
                                      )
                                    : s.loginPageLoadFailed,
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
                            url: WebUri(
                              _launchOAuthWhenReady
                                  ? 'about:blank'
                                  : _loginUri.toString(),
                            ),
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
                              _launchOAuthWhenReady = false;
                              controller.loadUrl(
                                urlRequest: URLRequest(
                                  url: WebUri(pending.toString()),
                                ),
                              );
                            } else if (_launchOAuthWhenReady) {
                              _launchOAuthWhenReady = false;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) unawaited(_startUnifiedOAuth());
                              });
                            }
                          },
                          shouldOverrideUrlLoading:
                              (controller, navigationAction) async {
                                final uri = navigationAction.request.url;
                                if (uri != null &&
                                    uri.scheme == 'dakit' &&
                                    uri.host == 'oauth') {
                                  _oauthCallbackSeen = true;
                                  _authorizationPageTimer?.cancel();
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
                              _socialCompletionFailed = false;
                            });
                            return true;
                          },
                          onLoadStart: (controller, url) {
                            _beginWebNavigation();
                            if (url != null && url.scheme != 'about') {
                              _lastMainFrameUri = Uri.tryParse(url.toString());
                            }
                            if (mounted) {
                              setState(() {
                                if (url != null && url.scheme != 'about') {
                                  _authorizationPageTimer?.cancel();
                                  _waitingForAuthorizationPage = false;
                                }
                                _loading = true;
                                _pageLoadFailed = false;
                              });
                            }
                          },
                          onLoadStop: (controller, url) {
                            if (url != null && url.scheme != 'about') {
                              _authorizationPageTimer?.cancel();
                              _lastMainFrameUri = Uri.tryParse(url.toString());
                            }
                            if (mounted) setState(() => _loading = false);
                            unawaited(
                              _inspectHumanVerification(
                                controller,
                                fallbackUri: url,
                                clearOnNegative: true,
                              ),
                            );
                            unawaited(
                              _triggerSelectedLoginMethod(controller, url),
                            );
                            // Report from any deviantart.com page. A sequence counter
                            // makes the latest page win, so an earlier anonymous page
                            // cannot overwrite a later signed-in page.
                            final uri = url;
                            if (uri != null &&
                                uri.host == 'www.deviantart.com') {
                              unawaited(_reportWebSession());
                            }
                          },
                          onReceivedHttpError: (controller, request, response) async {
                            final statusCode = response.statusCode ?? 0;
                            if (request.isForMainFrame != true ||
                                !isPotentialHumanVerificationStatus(
                                  statusCode,
                                ) ||
                                _recoveringHttp403) {
                              return;
                            }
                            final challenge = await _inspectHumanVerification(
                              controller,
                              fallbackUri: request.url,
                            );
                            // A newer onLoadStop/navigation owns the state when
                            // inspection was superseded. An interactive challenge
                            // must remain visible and must never become a proxy error.
                            if (challenge != false || !mounted) return;
                            // DeviantArt can return a transient HTML 403 after accepting
                            // the first WebView password submission. If the persistent
                            // userinfo cookie was already committed, move to Home so a
                            // fresh CSRF can be read instead of leaving the user staring
                            // at the stale error document.
                            final username = await _waitForCommittedUsername();
                            if (!mounted) return;
                            if (_humanVerificationActive) return;
                            final pageKind = classifyLoginHttpPage(
                              isMainFrame: request.isForMainFrame == true,
                              statusCode: statusCode,
                              username: username,
                              isHumanVerification: false,
                            );
                            if (pageKind == LoginHttpPageKind.ignored) {
                              return;
                            }
                            if (pageKind ==
                                LoginHttpPageKind.connectionFailure) {
                              setState(() => _pageLoadFailed = true);
                              AppLogger.instance.warning(
                                'auth',
                                'main-frame login returned HTTP 403 before a session '
                                    'cookie was committed and no human-verification '
                                    'document was found',
                              );
                              return;
                            }
                            AppLogger.instance.warning(
                              'auth',
                              'recovering committed WebView login after HTTP 403',
                            );
                            _recoveringHttp403 = true;
                            final recoveryUri = _activeAuthorizeUri ?? _homeUri;
                            await controller.loadUrl(
                              urlRequest: URLRequest(
                                url: WebUri(recoveryUri.toString()),
                              ),
                            );
                            _recoveringHttp403 = false;
                          },
                          onReceivedError: (controller, request, error) async {
                            if (request.isForMainFrame != true || !mounted) {
                              return;
                            }
                            final challenge = await _inspectHumanVerification(
                              controller,
                              fallbackUri: request.url,
                            );
                            if (challenge != false || !mounted) return;
                            if (_humanVerificationActive) return;
                            _authorizationPageTimer?.cancel();
                            AppLogger.instance.warning(
                              'auth',
                              'login page network error: ${error.type} '
                                  '${error.description}',
                            );
                            setState(() {
                              _loading = false;
                              _waitingForAuthorizationPage = false;
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
                                    _oauthCallbackSeen = true;
                                    _authorizationPageTimer?.cancel();
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
                            onLoadStart: (popupController, url) {
                              _beginWebNavigation();
                              if (mounted) {
                                setState(() {
                                  _loading = true;
                                  _pageLoadFailed = false;
                                });
                              }
                            },
                            onLoadStop: (popupController, url) async {
                              if (mounted) setState(() => _loading = false);
                              unawaited(
                                _inspectHumanVerification(
                                  popupController,
                                  fallbackUri: url,
                                  clearOnNegative: true,
                                ),
                              );
                              final uri = url == null
                                  ? null
                                  : Uri.tryParse(url.toString());
                              final username = await ref
                                  .read(webSessionProvider)
                                  .webUsername();
                              if (username.isEmpty || !mounted) return;
                              if (uri?.host == 'www.deviantart.com' ||
                                  uri?.scheme == 'about') {
                                final windowId = _popupWindowId;
                                // Prefer the provider's own window.close/postMessage
                                // completion. The fallback only takes over if that
                                // script stalls, avoiding the premature close that
                                // used to discard the first Google OAuth round trip.
                                unawaited(
                                  Future<void>.delayed(
                                    const Duration(milliseconds: 1500),
                                    () {
                                      if (mounted &&
                                          _popupWindowId == windowId) {
                                        unawaited(
                                          _finishSocialPopup(
                                            'provider callback fallback',
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                );
                              }
                            },
                            onCloseWindow: (controller) {
                              unawaited(_finishSocialPopup('window.close'));
                            },
                            onReceivedHttpError:
                                (controller, request, response) => unawaited(
                                  _handleSocialPopupHttpError(
                                    controller,
                                    request,
                                    response,
                                  ),
                                ),
                            onReceivedError: (controller, request, error) =>
                                unawaited(
                                  _handleSocialPopupError(
                                    controller,
                                    request,
                                    error,
                                  ),
                                ),
                          ),
                        if (_completingSocialSignIn ||
                            _waitingForAuthorizationPage)
                          Positioned.fill(
                            child: ColoredBox(
                              color: theme.scaffoldBackgroundColor,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      const CircularProgressIndicator(),
                                      const SizedBox(height: 20),
                                      Text(
                                        _completingSocialSignIn
                                            ? s.finishingSocialSignIn(
                                                _socialProviderName,
                                              )
                                            : s.openingOfficialAuthorization,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
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
                onPressed: _preparingBrowser
                    ? null
                    : () => _openBrowser(method: WebLoginMethod.deviantArt),
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
                    : () => _openBrowser(method: WebLoginMethod.google),
                icon: const Icon(Icons.account_circle_outlined),
                label: Text(s.signInWithGoogle),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _preparingBrowser
                    ? null
                    : () => _openBrowser(method: WebLoginMethod.apple),
                icon: const Icon(Icons.apple),
                label: Text(s.signInWithApple),
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
                color: _networkReachable == null
                    ? null
                    : _networkReachable!
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            _networkReachable == null
                                ? Icons.lan_outlined
                                : _networkReachable!
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_off_outlined,
                          ),
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
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await context.push('/settings/proxy');
                            if (mounted) unawaited(_testNetwork());
                          },
                          icon: const Icon(Icons.settings_ethernet),
                          label: Text(s.proxy),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
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
