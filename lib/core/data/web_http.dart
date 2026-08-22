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
