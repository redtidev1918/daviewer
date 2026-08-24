import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
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

enum HumanVerificationState { none, loading, active }

HumanVerificationState humanVerificationStateAfterHttpStatus({
  required HumanVerificationState current,
  required int statusCode,
}) {
  if (!isPotentialHumanVerificationStatus(statusCode) ||
      current == HumanVerificationState.active) {
    return current;
  }
  return HumanVerificationState.loading;
}

HumanVerificationState humanVerificationStateAfterInspection({
  required HumanVerificationState current,
  required bool detected,
  required int consecutiveCleanObservations,
}) {
  if (detected) return HumanVerificationState.active;
  if (current == HumanVerificationState.active &&
      consecutiveCleanObservations >= 2) {
    return HumanVerificationState.none;
  }
  return current;
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
  final uriPath = pageUri?.path.toLowerCase() ?? '';
  final challengeQuery =
      pageUri?.queryParameters.keys.any(
        (key) => const <String>{
          'challenge',
          'captcha',
          'cf_chl_tk',
          '__cf_chl_tk',
          'g-recaptcha-response',
          'h-captcha-response',
        }.contains(key.toLowerCase()),
      ) ??
      false;
  if (uriText.contains('/cdn-cgi/challenge-platform') ||
      uriText.contains('challenges.cloudflare.com') ||
      uriText.contains('/_sec/cp_challenge') ||
      uriText.contains('px-captcha') ||
      uriText.contains('cf-turnstile') ||
      uriText.contains('recaptcha') ||
      uriText.contains('hcaptcha') ||
      uriText.contains('arkoselabs') ||
      uriText.contains('funcaptcha') ||
      uriText.contains('captcha') ||
      (uriPath.contains('/challenge/') &&
          pageUri?.host != 'www.deviantart.com') ||
      challengeQuery) {
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
    'additional verification required',
    'unusual traffic',
    'prove you are not a robot',
    'complete the captcha',
    'verify your identity',
    'captcha',
    'recaptcha',
    'hcaptcha',
    'cloudflare ray id',
    '人机验证',
    '安全验证',
    '完成验证',
    '异常流量',
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
  if (!isPotentialHumanVerificationStatus(statusCode)) {
    return LoginHttpPageKind.ignored;
  }
  return statusCode == 403 && username.isNotEmpty
      ? LoginHttpPageKind.committedSession
      : LoginHttpPageKind.connectionFailure;
}

bool systemBrowserFollowsSelectedProxy(app_proxy.ProxySource source) =>
    source == app_proxy.ProxySource.system ||
    source == app_proxy.ProxySource.direct;

/// Reads provider names from DeviantArt's current server-rendered login page.
///
/// These names are display-only: authentication remains on the official page,
/// so a markup or provider change can never redirect credentials to app code.
List<String> discoverOfficialSocialProviders(String html) {
  final providers = <String>[];
  final seen = <String>{};
  final patterns = <RegExp>[
    RegExp(r'''aria-label=["']([^"']+)["']''', caseSensitive: false),
    RegExp(
      r'''continue\s+with\s+([A-Za-z0-9 .+_-]{1,32})''',
      caseSensitive: false,
    ),
  ];
  const ariaSocialLabels = <String>{
    'google',
    'apple',
    'facebook',
    'microsoft',
    'github',
  };
  for (var patternIndex = 0; patternIndex < patterns.length; patternIndex++) {
    final pattern = patterns[patternIndex];
    for (final match in pattern.allMatches(html)) {
      final raw = match.group(1)?.trim() ?? '';
      if (raw.isEmpty || raw.length > 32) continue;
      final normalized = raw.toLowerCase();
      if (patternIndex == 0 && !ariaSocialLabels.contains(normalized)) continue;
      if (const <String>{
        'email',
        'username',
        'password',
        'close',
        'menu',
      }.contains(normalized)) {
        continue;
      }
      if (seen.add(normalized)) providers.add(raw);
    }
  }
  return List<String>.unmodifiable(providers.take(6));
}

bool shouldActivateDeviantArtAccountForm({
  required bool alreadyActivated,
  required Uri? pageUri,
}) {
  if (alreadyActivated ||
      pageUri == null ||
      pageUri.host != 'www.deviantart.com') {
    return false;
  }
  final isJoinPage = pageUri.path == '/join' || pageUri.path == '/join/oauth2';
  return isJoinPage;
}

bool shouldResumeOAuthAfterEmbeddedProvider({
  required bool oauthSignedIn,
  required bool callbackSeen,
  required Uri? mainFrameUri,
}) {
  if (oauthSignedIn || callbackSeen) return false;
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
  HumanVerificationState _humanVerificationState = HumanVerificationState.none;
  bool _showBrowser = false;
  bool _preparingBrowser = false;
  bool _externalOAuthInProgress = false;
  bool _externalOAuthDelayed = false;
  bool _successfulExternalCloseScheduled = false;
  bool _launchOAuthWhenReady = false;
  bool _accountFormTriggered = false;
  bool _completingEmbeddedProvider = false;
  bool _waitingForAuthorizationPage = false;
  bool _oauthCallbackSeen = false;
  bool _testingNetwork = false;
  bool? _networkReachable;
  String _networkStatus = '';
  List<String> _officialSocialProviders = const <String>[];
  WebViewEnvironment? _webViewEnvironment;
  int _webViewGeneration = 0;
  int? _popupWindowId;
  Uri? _activeAuthorizeUri;
  Uri? _lastMainFrameUri;
  int _reportSeq = 0;
  int _providerDiscoverySeq = 0;
  int _humanVerificationInspectionSeq = 0;
  Timer? _authorizationPageTimer;
  Timer? _externalOAuthDelayTimer;
  Timer? _humanVerificationPollTimer;
  InAppWebViewController? _verificationController;
  bool _humanVerificationPollInFlight = false;
  int _humanVerificationNegativePolls = 0;
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
      if (mounted) {
        unawaited(_testNetwork());
        unawaited(_discoverSocialProviders());
      }
    });
    // OAuth starts only after the user chooses a method. The authorize request
    // then owns the complete login round trip, so a social provider never has
    // to establish a web session and start a second authorization afterwards.
  }

  @override
  void dispose() {
    _authorizationPageTimer?.cancel();
    _externalOAuthDelayTimer?.cancel();
    _humanVerificationPollTimer?.cancel();
    _proxyController?.removeListener(_onProxyChanged);
    unawaited(_launchSub?.cancel());
    final auth = ref.read(authControllerProvider);
    if (!auth.oauthSignedIn &&
        !_oauthCallbackSeen &&
        (_oauthRequested || auth.isLoggingIn)) {
      _bridge?.finishExternalAuthorization();
      unawaited(_authController.cancelLogin());
    }
    super.dispose();
  }

  void _onProxyChanged() {
    if (mounted) {
      setState(() {});
      unawaited(_discoverSocialProviders());
    }
  }

  Future<void> _discoverSocialProviders() async {
    final dio = ref.read(runtimeProvider).dio;
    if (dio == null) return;
    final seq = ++_providerDiscoverySeq;
    try {
      final response = await dio
          .get<String>(
            _loginUri.toString(),
            options: Options(
              responseType: ResponseType.plain,
              headers: const <String, String>{'User-Agent': webUserAgent},
            ),
          )
          .timeout(const Duration(seconds: 12));
      final providers = discoverOfficialSocialProviders(response.data ?? '');
      if (!mounted || seq != _providerDiscoverySeq) return;
      setState(() => _officialSocialProviders = providers);
    } on Object catch (error, stack) {
      AppLogger.instance.debug(
        'auth',
        'official social-provider discovery unavailable; using generic UI',
        error,
        stack,
      );
    }
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
      _externalOAuthDelayTimer?.cancel();
      _bridge?.finishExternalAuthorization();
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
    _clearHumanVerification();
    _controller = null;
    await _authController.cancelLogin();
    if (!mounted) return;
    _pendingAuthUri = null;
    _activeAuthorizeUri = null;
    setState(() {
      _showBrowser = false;
      _pageLoadFailed = false;
    });
    await _openBrowser();
  }

  Future<void> _closeBrowser() async {
    _authorizationPageTimer?.cancel();
    _clearHumanVerification();
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

  Future<void> _openBrowser() async {
    if (_preparingBrowser) return;
    _clearHumanVerification();
    final oauthSignedIn = ref.read(authControllerProvider).oauthSignedIn;
    setState(() {
      _preparingBrowser = true;
      _launchOAuthWhenReady = !oauthSignedIn;
      _waitingForAuthorizationPage = !oauthSignedIn;
      _accountFormTriggered = false;
      _completingEmbeddedProvider = false;
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

  bool get _externalOAuthSupported =>
      Platform.isAndroid || Platform.isMacOS || Platform.isWindows;

  Future<void> _startExternalOAuth() async {
    if (!_externalOAuthSupported ||
        _externalOAuthInProgress ||
        _preparingBrowser) {
      return;
    }
    var auth = ref.read(authControllerProvider);
    if (auth.oauthSignedIn) {
      unawaited(_leaveLogin());
      return;
    }
    if (auth.isLoggingIn || _oauthRequested) {
      await _authController.cancelLogin();
      if (!mounted) return;
      auth = ref.read(authControllerProvider);
      if (auth.oauthSignedIn) {
        unawaited(_leaveLogin());
        return;
      }
    }
    final bridge = _bridge;
    if (bridge == null) return;
    bridge.launchNextExternally();
    setState(() {
      _externalOAuthInProgress = true;
      _externalOAuthDelayed = false;
      _oauthRequested = true;
      _networkStatus = '';
    });
    _externalOAuthDelayTimer?.cancel();
    _externalOAuthDelayTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && _externalOAuthInProgress) {
        setState(() => _externalOAuthDelayed = true);
      }
    });
    try {
      await _authController.login();
    } finally {
      _externalOAuthDelayTimer?.cancel();
      bridge.finishExternalAuthorization();
      _oauthRequested = false;
      if (mounted) {
        setState(() => _externalOAuthInProgress = false);
      }
    }
    if (mounted && ref.read(authControllerProvider).oauthSignedIn) {
      _scheduleSuccessfulExternalClose();
    }
  }

  void _scheduleSuccessfulExternalClose() {
    if (_successfulExternalCloseScheduled || !mounted) return;
    _successfulExternalCloseScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_leaveLogin());
    });
  }

  Future<void> _cancelExternalOAuth() async {
    _externalOAuthDelayTimer?.cancel();
    _bridge?.finishExternalAuthorization();
    await _authController.cancelLogin();
    _oauthRequested = false;
    if (mounted) setState(() => _externalOAuthInProgress = false);
  }

  Future<void> _reopenExternalOAuth() async {
    await _bridge?.reopenExternalAuthorization();
  }

  Future<void> _triggerDeviantArtAccountForm(
    InAppWebViewController controller,
    WebUri? url,
  ) async {
    if (!shouldActivateDeviantArtAccountForm(
      alreadyActivated: _accountFormTriggered,
      pageUri: url == null ? null : Uri.tryParse(url.toString()),
    )) {
      return;
    }
    for (final delay in <Duration>[
      Duration.zero,
      const Duration(milliseconds: 250),
      const Duration(milliseconds: 600),
    ]) {
      if (delay != Duration.zero) await Future<void>.delayed(delay);
      if (!mounted || _accountFormTriggered) return;
      try {
        final clicked = await controller.evaluateJavascript(
          source: '''(() => {
                  const links = Array.from(document.querySelectorAll('a[href*="/users/login"]'));
                  const target = links.find((link) => (link.textContent || '').toLowerCase().includes('log in')) || links[0];
                  if (!target) return false;
                  target.click();
                  return true;
                })()''',
        );
        if (clicked == true) {
          _accountFormTriggered = true;
          AppLogger.instance.info(
            'auth',
            'opened the DeviantArt account form from the OAuth join page',
          );
          return;
        }
      } on Object catch (error, stack) {
        AppLogger.instance.warning(
          'auth',
          'could not activate the DeviantArt account form',
          error,
          stack,
        );
      }
    }
  }

  Future<void> _finishEmbeddedProvider(String reason) async {
    if (_completingEmbeddedProvider) return;
    if (mounted) {
      setState(() {
        _popupWindowId = null;
        _completingEmbeddedProvider = true;
        _loading = true;
      });
      _resumeMainVerificationMonitor();
    }
    AppLogger.instance.info(
      'auth',
      'embedded provider window finished ($reason); reconciling the same OAuth transaction',
    );

    final username = await _waitForCommittedUsername();
    if (!mounted) return;
    if (username.isEmpty) {
      setState(() {
        _completingEmbeddedProvider = false;
        _loading = false;
        _pageLoadFailed = true;
      });
      AppLogger.instance.warning(
        'auth',
        'embedded provider window closed without a committed DeviantArt session',
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
        shouldResumeOAuthAfterEmbeddedProvider(
          oauthSignedIn: auth.oauthSignedIn,
          callbackSeen: _oauthCallbackSeen,
          mainFrameUri: _lastMainFrameUri,
        )) {
      await _controller?.loadUrl(
        urlRequest: URLRequest(url: WebUri(authorizeUri.toString())),
      );
    }
    if (!mounted) return;
    setState(() => _completingEmbeddedProvider = false);
  }

  bool get _showHumanVerificationNotice =>
      _humanVerificationState != HumanVerificationState.none;
  bool get _humanVerificationActive =>
      _humanVerificationState == HumanVerificationState.active;
  bool get _humanVerificationSuspected =>
      _humanVerificationState == HumanVerificationState.loading;

  void _clearHumanVerification() {
    _humanVerificationNegativePolls = 0;
    if (!mounted) {
      _humanVerificationState = HumanVerificationState.none;
      return;
    }
    if (_showHumanVerificationNotice) {
      setState(() => _humanVerificationState = HumanVerificationState.none);
    }
  }

  void _announceHumanVerification({required bool suspected}) {
    if (!mounted || _showHumanVerificationNotice) return;
    final s = strings(ref.read(appLanguageProvider));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            suspected ? s.humanVerificationChecking : s.humanVerificationHint,
          ),
          duration: const Duration(seconds: 8),
        ),
      );
  }

  void _markHumanVerificationSuspected(int statusCode) {
    if (!mounted) return;
    _announceHumanVerification(suspected: true);
    setState(() {
      _humanVerificationState = humanVerificationStateAfterHttpStatus(
        current: _humanVerificationState,
        statusCode: statusCode,
      );
      _pageLoadFailed = false;
      _loading = false;
      _waitingForAuthorizationPage = false;
    });
    _authorizationPageTimer?.cancel();
  }

  void _markHumanVerificationActive() {
    if (!mounted) return;
    final alreadyNotified = _showHumanVerificationNotice;
    if (!alreadyNotified) {
      _announceHumanVerification(suspected: false);
    }
    setState(() {
      _humanVerificationState = humanVerificationStateAfterInspection(
        current: _humanVerificationState,
        detected: true,
        consecutiveCleanObservations: 0,
      );
      _pageLoadFailed = false;
      _loading = false;
      _waitingForAuthorizationPage = false;
    });
    _humanVerificationNegativePolls = 0;
    _authorizationPageTimer?.cancel();
  }

  void _monitorHumanVerification(InAppWebViewController controller) {
    _verificationController = controller;
    _humanVerificationPollTimer ??= Timer.periodic(
      const Duration(milliseconds: 1250),
      (_) => unawaited(_pollHumanVerification()),
    );
    unawaited(_pollHumanVerification());
  }

  void _resumeMainVerificationMonitor({bool clearNotice = true}) {
    if (clearNotice) _clearHumanVerification();
    final controller = _controller;
    if (controller != null) _monitorHumanVerification(controller);
  }

  Future<void> _pollHumanVerification() async {
    final controller = _verificationController;
    if (!mounted ||
        !_showBrowser ||
        controller == null ||
        _humanVerificationPollInFlight) {
      return;
    }
    _humanVerificationPollInFlight = true;
    try {
      await _inspectHumanVerification(
        controller,
        clearOnNegative: _humanVerificationActive,
        retryWhileLoading: false,
      );
    } finally {
      _humanVerificationPollInFlight = false;
    }
  }

  void _beginWebNavigation(InAppWebViewController controller, WebUri? url) {
    _humanVerificationInspectionSeq++;
    _humanVerificationNegativePolls = 0;
    _monitorHumanVerification(controller);
    if (looksLikeHumanVerificationPage(
      pageUri: url == null ? null : Uri.tryParse(url.toString()),
    )) {
      _markHumanVerificationActive();
    }
  }

  /// Returns `null` when this inspection was superseded by a newer navigation.
  Future<bool?> _inspectHumanVerification(
    InAppWebViewController controller, {
    WebUri? fallbackUri,
    bool clearOnNegative = false,
    bool retryWhileLoading = true,
  }) async {
    // Multiple callbacks (HTTP error + load stop) may inspect the same
    // document concurrently. Only a real navigation invalidates them; one
    // callback must not cancel another callback that still owns HTTP error
    // classification for the same page.
    final inspectionSeq = _humanVerificationInspectionSeq;
    final delays = retryWhileLoading
        ? const <Duration>[
            Duration.zero,
            Duration(milliseconds: 250),
            Duration(milliseconds: 750),
            Duration(milliseconds: 1500),
          ]
        : const <Duration>[Duration.zero];
    for (final delay in delays) {
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
              'iframe[src*="recaptcha" i]',
              'iframe[src*="hcaptcha" i]',
              'iframe[src*="arkoselabs" i]',
              '[id*="captcha" i]',
              '[class*="captcha" i]',
              '[id*="challenge-running" i]',
              '[class*="challenge-running" i]',
              '[class*="cf-turnstile" i]',
              '[data-sitekey]',
              '.g-recaptcha',
              '.h-captcha',
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
              _markHumanVerificationActive();
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
      _humanVerificationNegativePolls++;
      final nextState = humanVerificationStateAfterInspection(
        current: _humanVerificationState,
        detected: false,
        consecutiveCleanObservations: _humanVerificationNegativePolls,
      );
      if (nextState == HumanVerificationState.none) {
        _clearHumanVerification();
      }
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
      await _finishEmbeddedProvider('provider navigation completed');
      return;
    }
    AppLogger.instance.warning(
      'auth',
      'social login popup network error: ${error.type} ${error.description}',
    );
    setState(() {
      _loading = false;
      _pageLoadFailed = true;
      _popupWindowId = null;
    });
    _resumeMainVerificationMonitor();
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
    _markHumanVerificationSuspected(statusCode);
    final challenge = await _inspectHumanVerification(
      controller,
      fallbackUri: request.url,
    );
    if (challenge != false || !mounted) return;
    _clearHumanVerification();
    final username = await ref.read(webSessionProvider).webUsername();
    if (!mounted) return;
    if (_humanVerificationActive) return;
    if (username.isNotEmpty) {
      await _finishEmbeddedProvider('provider HTTP response completed');
      return;
    }
    AppLogger.instance.warning(
      'auth',
      'social login popup returned HTTP $statusCode without a challenge page',
    );
    setState(() {
      _loading = false;
      _pageLoadFailed = true;
      _popupWindowId = null;
    });
    _resumeMainVerificationMonitor();
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
        final s = strings(ref.read(appLanguageProvider));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.loginSuccess)));
        if (_externalOAuthInProgress) {
          _bridge?.finishExternalAuthorization();
          _externalOAuthInProgress = false;
          _scheduleSuccessfulExternalClose();
          return;
        }
        _closeAfterReport = true;
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
                    _resumeMainVerificationMonitor();
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
                  if (_showHumanVerificationNotice)
                    Material(
                      color: theme.colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            _humanVerificationSuspected
                                ? SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          theme.colorScheme.onTertiaryContainer,
                                    ),
                                  )
                                : Icon(
                                    Icons.verified_user_outlined,
                                    size: 20,
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                  ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Semantics(
                                liveRegion: true,
                                child: Text(
                                  _humanVerificationSuspected
                                      ? s.humanVerificationChecking
                                      : s.humanVerificationHint,
                                  style: TextStyle(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: s.refresh,
                              onPressed: () => unawaited(
                                _verificationController?.reload() ??
                                    Future<void>.value(),
                              ),
                              icon: const Icon(Icons.refresh),
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
                            domStorageEnabled: true,
                            // Keep the official account form usable on narrow
                            // screens. Supported social sign-in is deliberately
                            // routed through the system browser instead.
                            userAgent: webUserAgent,
                            // Opaque: a transparent platform view uses a slower
                            // composition path and makes the keyboard animation heavier.
                            transparentBackground: false,
                          ),
                          onWebViewCreated: (controller) {
                            _controller = controller;
                            _monitorHumanVerification(controller);
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
                                  _clearHumanVerification();
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
                            // Preserve official popup navigation as a compatibility
                            // fallback for the embedded account route. The supported
                            // Google/Apple/Facebook route is the system-browser action
                            // on the native entry screen.
                            if (!mounted) return false;
                            setState(() {
                              _popupWindowId = action.windowId;
                              _loading = true;
                              _pageLoadFailed = false;
                            });
                            return true;
                          },
                          onLoadStart: (controller, url) {
                            _beginWebNavigation(controller, url);
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
                              _triggerDeviantArtAccountForm(controller, url),
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
                            _markHumanVerificationSuspected(statusCode);
                            final challenge = await _inspectHumanVerification(
                              controller,
                              fallbackUri: request.url,
                            );
                            // A newer onLoadStop/navigation owns the state when
                            // inspection was superseded. An interactive challenge
                            // must remain visible and must never become a proxy error.
                            if (challenge != false || !mounted) return;
                            _clearHumanVerification();
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
                              domStorageEnabled: true,
                              userAgent: webUserAgent,
                              transparentBackground: false,
                            ),
                            onWebViewCreated: (controller) {
                              _monitorHumanVerification(controller);
                            },
                            shouldOverrideUrlLoading:
                                (popupController, navigationAction) async {
                                  final uri = navigationAction.request.url;
                                  if (uri != null &&
                                      uri.scheme == 'dakit' &&
                                      uri.host == 'oauth') {
                                    _oauthCallbackSeen = true;
                                    _authorizationPageTimer?.cancel();
                                    _clearHumanVerification();
                                    _bridge?.addCallback(uri);
                                    if (mounted) {
                                      setState(() => _popupWindowId = null);
                                      _resumeMainVerificationMonitor();
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
                              _beginWebNavigation(popupController, url);
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
                                          _finishEmbeddedProvider(
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
                              _resumeMainVerificationMonitor();
                              unawaited(
                                _finishEmbeddedProvider('window.close'),
                              );
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
                        if (_completingEmbeddedProvider ||
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
                                        s.openingOfficialAuthorization,
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
    final oauthSignedIn = ref.watch(authControllerProvider).oauthSignedIn;
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
              if (_externalOAuthSupported && !oauthSignedIn) ...[
                FilledButton.icon(
                  onPressed: _externalOAuthInProgress || _preparingBrowser
                      ? null
                      : _startExternalOAuth,
                  icon: _externalOAuthInProgress
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_browser),
                  label: Text(
                    s.signInWithSocialBrowser(_officialSocialProviders),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.socialBrowserDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (_externalOAuthInProgress) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          Text(
                            _externalOAuthDelayed
                                ? s.externalBrowserDelayed
                                : s.externalBrowserWaiting,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: _reopenExternalOAuth,
                                icon: const Icon(Icons.open_in_browser),
                                label: Text(s.reopenBrowser),
                              ),
                              TextButton.icon(
                                onPressed: _cancelExternalOAuth,
                                icon: const Icon(Icons.close),
                                label: Text(s.cancel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: _preparingBrowser || _externalOAuthInProgress
                    ? null
                    : _openBrowser,
                icon: _preparingBrowser
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(
                  _preparingBrowser
                      ? s.openingOfficialLogin
                      : oauthSignedIn
                      ? s.syncPersonalizedWebSession
                      : s.signInWithDeviantArt,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                oauthSignedIn
                    ? s.syncPersonalizedWebSessionDescription
                    : s.embeddedAccountDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (ref.watch(authControllerProvider).error
                  case final error?) ...[
                const SizedBox(height: 12),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(s.loginFailed(friendlyErrorMessage(error))),
                  ),
                ),
              ],
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
                      if (_externalOAuthSupported &&
                          !oauthSignedIn &&
                          !systemBrowserFollowsSelectedProxy(
                            ref
                                    .watch(runtimeProvider)
                                    .proxyController
                                    ?.source ??
                                app_proxy.ProxySource.direct,
                          )) ...[
                        const SizedBox(height: 8),
                        Text(
                          s.externalBrowserProxyHint,
                          style: TextStyle(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
