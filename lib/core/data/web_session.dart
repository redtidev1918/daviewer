import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Thrown when the personalized home feed is requested without a usable web
/// session so the UI can show a "sign in on web" prompt instead of a raw error.
final class WebLoginRequired implements Exception {
  const WebLoginRequired();

  @override
  String toString() => 'WebLoginRequired';
}

/// Reads the deviantart.com cookies owned by the embedded WebView so the
/// native `rfy/deviations` feed can send the web session Cookie header.
///
/// The CSRF token and login state are read from the WebView page itself (via
/// JavaScript) and stored in the sign-in state; they cannot be fetched with a
/// plain HTTP client because deviantart.com's HTML pages reject non-browser
/// clients.
final class WebSession {
  const WebSession();

  static final Uri _home = Uri.parse('https://www.deviantart.com/');

  /// Serializes the deviantart.com cookies into a `Cookie` header value.
  Future<String> cookieHeader() async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(_home.toString()),
    );
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }
}
