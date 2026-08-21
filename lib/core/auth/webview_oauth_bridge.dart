import 'dart:async';

import 'package:dakit_core/dakit_core.dart';

import '../network/desktop_uri_launcher.dart';

/// Bridges DAKit's OAuth coordinator with the in-app home WebView.
///
/// When the home WebView is available, OAuth authorize URLs are loaded there
/// instead of the external system browser. Because the WebView already owns
/// the deviantart.com web-session cookies, an already logged-in user only has
/// to confirm the OAuth consent screen (or is redirected straight through).
/// The WebView forwards `dakit://oauth/callback` back through [callbacks] so
/// the existing DAKit PKCE flow completes normally.
final class WebViewOAuthBridge implements ExternalUriLauncher {
  WebViewOAuthBridge({ExternalUriLauncher? fallback})
    : _fallback = fallback ?? const DesktopUriLauncher();

  final ExternalUriLauncher _fallback;
  final StreamController<Uri> _launchController = StreamController<Uri>.broadcast();
  final StreamController<Uri> _callbackController = StreamController<Uri>.broadcast();

  /// Authorize URLs that should be loaded in the home WebView.
  Stream<Uri> get launchRequests => _launchController.stream;

  /// OAuth callbacks captured from the home WebView.
  Stream<Uri> get callbacks => _callbackController.stream;

  void addCallback(Uri uri) {
    if (uri.scheme != 'dakit' || uri.host != 'oauth') return;
    _callbackController.add(uri);
  }

  @override
  Future<void> launch(Uri uri) async {
    if (_launchController.hasListener) {
      _launchController.add(uri);
    } else {
      await _fallback.launch(uri);
    }
  }

  Future<void> dispose() async {
    await _launchController.close();
    await _callbackController.close();
  }
}
