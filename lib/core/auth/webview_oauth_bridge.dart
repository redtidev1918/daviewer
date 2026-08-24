import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/foundation.dart';

import '../network/desktop_uri_launcher.dart';

/// Routes each DAKit OAuth transaction through the login surface selected by
/// the user.
///
/// DeviantArt-account login stays in the WebView so it can establish the web
/// Cookie/CSRF session. Social login arms one authorization for the operating
/// system browser, where embedded-user-agent restrictions do not apply. Both
/// routes return `dakit://oauth/callback` through [callbacks] and complete the
/// same PKCE coordinator.
final class WebViewOAuthBridge implements ExternalUriLauncher {
  WebViewOAuthBridge({ExternalUriLauncher? fallback})
    : _fallback = fallback ?? const DesktopUriLauncher();

  final ExternalUriLauncher _fallback;
  final StreamController<Uri> _launchController =
      StreamController<Uri>.broadcast();
  final StreamController<Uri> _callbackController =
      StreamController<Uri>.broadcast();
  bool _launchNextExternally = false;
  Uri? _externalAuthorizationUri;

  /// Authorize URLs that should be loaded in the home WebView.
  Stream<Uri> get launchRequests => _launchController.stream;

  /// OAuth callbacks captured from the home WebView.
  CallbackUriSource get callbacks =>
      _StreamCallbackSource(_callbackController.stream);

  void addCallback(Uri uri) {
    if (uri.scheme != 'dakit' || uri.host != 'oauth') return;
    _callbackController.add(uri);
  }

  /// Routes exactly one upcoming OAuth authorization through the operating
  /// system browser.
  ///
  /// Google intentionally rejects embedded user-agents. Keeping this as a
  /// one-shot choice prevents a social-login attempt from silently changing
  /// later DeviantArt-account logins, which still benefit from the WebView's
  /// cookies and app-level proxy.
  void launchNextExternally() {
    _launchNextExternally = true;
  }

  /// Clears a one-shot route that was armed but cancelled before DAKit called
  /// [launch].
  void cancelExternalLaunch() {
    _launchNextExternally = false;
  }

  bool get canReopenExternalAuthorization => _externalAuthorizationUri != null;

  Future<void> reopenExternalAuthorization() async {
    final uri = _externalAuthorizationUri;
    if (uri != null) await _fallback.launch(uri);
  }

  void finishExternalAuthorization() {
    _externalAuthorizationUri = null;
    _launchNextExternally = false;
  }

  @override
  Future<void> launch(Uri uri) async {
    if (_launchNextExternally) {
      _launchNextExternally = false;
      _externalAuthorizationUri = uri;
      debugPrint('[oauth] routing authorize to system browser');
      try {
        await _fallback.launch(uri);
      } on Object {
        _externalAuthorizationUri = null;
        rethrow;
      }
      return;
    }
    // The WebLoginScreen subscribes in initState right after its route is
    // pushed, so give it a short grace period before falling back to the
    // system browser. Falling back too eagerly would leave the embedded web
    // session out of sync with the OAuth account.
    for (var i = 0; i < 25 && !_launchController.hasListener; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (_launchController.hasListener) {
      debugPrint('[oauth] routing authorize to embedded WebView');
      _launchController.add(uri);
    } else {
      debugPrint('[oauth] NO WebView listener -> system browser fallback');
      await _fallback.launch(uri);
    }
  }

  Future<void> dispose() async {
    await _launchController.close();
    await _callbackController.close();
  }
}

final class _StreamCallbackSource implements CallbackUriSource {
  const _StreamCallbackSource(this._stream);

  final Stream<Uri> _stream;

  @override
  Stream<Uri> get uris => _stream;
}
