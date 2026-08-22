import 'package:dio/dio.dart';

import 'web_user_agent.dart';

/// dio options for DeviantArt's private web endpoints: a JSON response type,
/// the embedded WebView's Cookie header, and a browser-like user agent.
Options webSessionOptions(String cookieHeader) => Options(
  responseType: ResponseType.json,
  headers: <String, dynamic>{
    'Accept': 'application/json',
    'Cookie': cookieHeader,
    'User-Agent': webUserAgent,
  },
);

/// dio options for a DeviantArt HTML page fetched with the embedded browser's
/// cookies. This is intentionally separate from [webSessionOptions]: forcing
/// JSON for an artwork page makes dio try to decode the HTML response.
Options webPageOptions(String cookieHeader) => Options(
  responseType: ResponseType.plain,
  headers: <String, dynamic>{
    'Accept': 'text/html,application/xhtml+xml',
    if (cookieHeader.isNotEmpty) 'Cookie': cookieHeader,
    'User-Agent': webUserAgent,
  },
);
