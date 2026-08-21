import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Thrown when the personalized home feed is requested without a web session
/// so the UI can show a "sign in on web" prompt instead of a raw error.
final class WebLoginRequired implements Exception {
  const WebLoginRequired();

  @override
  String toString() => 'WebLoginRequired';
}

/// The web session credentials the native `rfy/deviations` feed needs.
final class WebSessionInfo {
  const WebSessionInfo({
    required this.cookieHeader,
    required this.csrfToken,
    required this.isLoggedIn,
    required this.username,
  });

  final String cookieHeader;
  final String csrfToken;
  final bool isLoggedIn;

  /// The username signed in on the web (`''` when anonymous or unknown).
  final String username;
}

/// Reads the DeviantArt web session established by the in-app WebView so the
/// native home feed can call the private `rfy/deviations` endpoint.
///
/// The WebView only owns the session; after the user signs in there, the
/// cookies live in the platform cookie store and the CSRF token is embedded in
/// a freshly fetched page, so this class works even when no WebView is mounted.
final class WebSession {
  const WebSession(this._dio);

  final Dio _dio;

  static final Uri _home = Uri.parse('https://www.deviantart.com/');

  Future<WebSessionInfo> read() async {
    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(_home.toString()),
    );
    final cookieHeader = cookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');

    final response = await _dio.get<String>(
      _home.toString(),
      options: Options(
        responseType: ResponseType.plain,
        headers: <String, dynamic>{
          if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
          'User-Agent': _userAgent,
        },
      ),
    );
    final html = response.data ?? '';
    final csrf = RegExp("__CSRF_TOKEN__ = '([^']+)'").firstMatch(html)?.group(1) ?? '';
    // The initial state is a JSON string with escaped quotes, so the key is
    // serialized as \"isLoggedIn\":true — match the literal backslash-quote.
    final isLoggedIn =
        RegExp(r'\\"isLoggedIn\\":(true|false)').firstMatch(html)?.group(1) ==
        'true';
    // The web username lives in @@publicSession.user.username; "anonymous"
    // means nobody is signed in on the web.
    final username =
        RegExp(r'@@publicSession[^@]{0,300}?username\\":\\"([^\\"]+)')
            .firstMatch(html)
            ?.group(1) ??
        '';

    return WebSessionInfo(
      cookieHeader: cookieHeader,
      csrfToken: csrf,
      isLoggedIn: isLoggedIn,
      username: username,
    );
  }

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
}
