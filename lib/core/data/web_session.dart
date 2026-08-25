import 'dart:convert';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Reads deviantart.com cookies owned by the hidden public browser so
/// website-only metadata adapters can reuse its anonymous session.
///
/// The CSRF token is read from the browser page because some undocumented
/// endpoints reject a plain HTTP client even when the page is public.
final class WebSession {
  const WebSession(this._cookieManager);

  final CookieManager Function() _cookieManager;

  static final Uri _home = Uri.parse('https://www.deviantart.com/');

  /// Serializes the deviantart.com cookies into a `Cookie` header value.
  Future<String> cookieHeader() async {
    try {
      final cookies = await _cookieManager().getCookies(
        url: WebUri(_home.toString()),
      );
      return cookies
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join('; ');
    } on Object {
      // The cookie manager can be unavailable very early in startup; an empty
      // header simply makes the feed report an auth error, which the UI maps
      // to a sign-in prompt rather than a crash.
      return '';
    }
  }

  /// The username signed in on deviantart.com, read from the long-lived
  /// `userinfo` cookie. Returns `''` when anonymous. This is far more reliable
  /// than scraping `__INITIAL_STATE__` from a page that may not be the home
  /// page (login/authorize pages lack the full session state).
  Future<String> webUsername() async {
    try {
      final cookies = await _cookieManager().getCookies(
        url: WebUri(_home.toString()),
      );
      for (final cookie in cookies) {
        if (cookie.name != 'userinfo') continue;
        final decoded = Uri.decodeComponent(cookie.value);
        final jsonPart = decoded.split(';').last;
        final data = jsonDecode(jsonPart);
        if (data is Map && data['username'] is String) {
          return (data['username'] as String).trim();
        }
      }
    } on Object {
      // Best effort; treat as anonymous on failure.
    }
    return '';
  }
}
