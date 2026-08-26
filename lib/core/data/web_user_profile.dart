import 'package:dio/dio.dart';

import 'web_http.dart';

/// Profile facts DeviantArt's official `user/profile` does not expose, read
/// from the website's private about-tab endpoint
/// `_puppy/dauserprofile/init/about`.
///
/// The official API has no watchers count and no join date, so this adapter
/// fills those gaps for the artist header. Every field is optional: the page
/// shape is volatile, so the UI must render fine when any of them is missing.
final class WebUserProfileInfo {
  const WebUserProfileInfo({this.watchers, this.joinDate, this.tagline});

  /// How many deviants watch this artist (official API does not provide it).
  final int? watchers;

  /// When the account joined, from the about-tab `joinDate` field.
  final DateTime? joinDate;

  /// The website's tagline, when the official profile did not carry one.
  final String? tagline;
}

/// Fetches the about-tab payload for one artist. Needs a web session (Cookie +
/// CSRF; an anonymous deviantart.com visit suffices — the endpoint is public).
final class WebUserProfileFetcher {
  const WebUserProfileFetcher(this._dio);

  final Dio _dio;

  static final Uri _endpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dauserprofile/init/about',
  );

  Future<WebUserProfileInfo> fetch({
    required String username,
    required String cookieHeader,
    required String csrfToken,
  }) async {
    final response = await _dio.get<Object?>(
      _endpoint.toString(),
      queryParameters: <String, dynamic>{
        'username': username.toLowerCase(),
        'csrf_token': csrfToken,
      },
      options: webSessionOptions(cookieHeader),
    );
    return parseJson(response.data);
  }

  /// Tolerant parse: any missing or reshaped field degrades to `null` rather
  /// than failing the profile header.
  static WebUserProfileInfo parseJson(Object? data) {
    if (data is! Map) return const WebUserProfileInfo();
    final pageExtra = data['pageExtraData'];
    if (pageExtra is! Map) return const WebUserProfileInfo();

    int? watchers;
    final stats = pageExtra['stats'];
    if (stats is Map) {
      final raw = stats['watchers'];
      if (raw is num) watchers = raw.toInt();
    }

    DateTime? joinDate;
    final rawDate = pageExtra['joinDate'];
    if (rawDate is String) {
      joinDate = DateTime.tryParse(rawDate);
    }

    final rawTagline = pageExtra['gruserTagline'];
    final tagline = rawTagline is String && rawTagline.isNotEmpty
        ? rawTagline
        : null;

    return WebUserProfileInfo(
      watchers: watchers,
      joinDate: joinDate,
      tagline: tagline,
    );
  }
}
