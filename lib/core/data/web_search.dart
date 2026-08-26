import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'rfy_feed.dart' show WebDeviationMapper;
import 'web_http.dart';

/// Fetches DeviantArt's real search results from the website's private
/// `_puppy/dabrowse/search/deviations` endpoint.
///
/// The official OAuth API no longer exposes a deviation search endpoint (the
/// old `browse/search` was removed along with the other legacy `/browse`
/// routes), so `browse/home?q=` is only a coarse fallback. This fetcher
/// mirrors the approach of the gallery-dl extractor: the web endpoint returns
/// clean JSON and needs the embedded WebView's Cookie header plus a
/// `csrf_token`, exactly like the personalized `rfy/deviations` feed.
final class WebSearchFetcher {
  const WebSearchFetcher(this._dio);

  final Dio _dio;

  static final Uri _endpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dabrowse/search/deviations',
  );

  /// Fetches one page of search results. [cursor] is either a numeric offset
  /// (produced by our own [Page.nextCursor]) or a server-side cursor from the
  /// endpoint's `nextCursor` field.
  Future<Page<Artwork>> fetch({
    required String query,
    required String cookieHeader,
    required String csrfToken,
    String? cursor,
  }) async {
    final offset = int.tryParse(cursor ?? '');
    final response = await _dio.get<Object?>(
      _endpoint.toString(),
      queryParameters: <String, dynamic>{
        'q': query,
        'limit': 24,
        'mature_content': true,
        'include_session': 'false',
        'csrf_token': csrfToken,
        'offset': ?offset,
        'cursor': ?cursor,
      },
      options: webSessionOptions(cookieHeader),
    );
    return parseJson(response.data);
  }

  /// Parses one `search/deviations` response into a [Page] of artworks.
  ///
  /// The payload carries the same shared website deviation shape as the rfy
  /// feed and `gallection/contents`; pagination uses `hasMore` plus
  /// `nextCursor` (preferred) or a numeric `nextOffset`.
  static Page<Artwork> parseJson(Object? data) {
    if (data is! Map) {
      throw const FormatException('Unexpected search response shape.');
    }
    final rawDeviations = data['deviations'];
    if (rawDeviations is! List) {
      throw const FormatException('Missing search deviations list.');
    }
    final items = <Artwork>[
      for (final raw in rawDeviations)
        if (raw is Map) WebDeviationMapper.mapDeviation(raw),
    ];
    final hasMore = data['hasMore'] == true;
    final nextCursor = data['nextCursor'] as String?;
    final nextOffset = data['nextOffset'];
    final String? continuation;
    if (nextCursor != null && nextCursor.isNotEmpty) {
      continuation = nextCursor;
    } else if (hasMore && nextOffset is int) {
      continuation = '$nextOffset';
    } else {
      continuation = null;
    }
    return Page<Artwork>(
      items: items,
      hasMore: hasMore,
      nextCursor: continuation,
    );
  }
}
