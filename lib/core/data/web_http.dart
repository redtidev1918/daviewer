import 'package:dio/dio.dart';

import 'web_user_agent.dart';

/// Dio options for DeviantArt's private web endpoints: a JSON response type,
/// an anonymous hidden-browser Cookie header, and a browser-like user agent.
Options webSessionOptions(String cookieHeader) => Options(
  responseType: ResponseType.json,
  headers: <String, dynamic>{
    'Accept': 'application/json',
    'Cookie': cookieHeader,
    'User-Agent': webUserAgent,
  },
);

/// Dio options for a DeviantArt HTML page fetched with the hidden browser's
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
