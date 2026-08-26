import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'rfy_feed.dart' show WebDeviationMapper;
import 'web_http.dart';

/// Searches one artist's own gallery by keyword via the website's private
/// `_puppy/dashared/gallection/search` endpoint — the same source behind
/// `deviantart.com/{user}/gallery?q=…` and the same approach as the
/// gallery-dl extractor.
///
/// The official API has no equivalent (neither `gallery/…` nor
/// `gallery/folders` accept a query), so this adapter needs a web session
/// (Cookie + CSRF; an anonymous deviantart.com visit suffices). Results carry
/// the shared website deviation shape, so [WebDeviationMapper] applies
/// directly; pagination uses `hasMore` plus a numeric `nextOffset`.
final class WebGallerySearchFetcher {
  const WebGallerySearchFetcher(this._dio);

  final Dio _dio;

  static final Uri _endpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dashared/gallection/search',
  );

  /// Fetches one page of gallery search results. [cursor] is a numeric offset
  /// produced by our own [Page.nextCursor].
  Future<Page<Artwork>> fetch({
    required String username,
    required String query,
    required String cookieHeader,
    required String csrfToken,
    String? cursor,
  }) async {
    final offset = int.tryParse(cursor ?? '');
    final response = await _dio.get<Object?>(
      _endpoint.toString(),
      queryParameters: <String, dynamic>{
        'username': username.toLowerCase(),
        'type': 'gallery',
        'order': 'most-recent',
        'q': query,
        'limit': 24,
        'mature_content': true,
        'csrf_token': csrfToken,
        'offset': ?offset,
      },
      options: webSessionOptions(cookieHeader),
    );
    return parseJson(response.data);
  }

  /// Parses one `gallection/search` response into a [Page] of artworks.
  static Page<Artwork> parseJson(Object? data) {
    if (data is! Map) {
      throw const FormatException('Unexpected gallery search response shape.');
    }
    final rawResults = data['results'];
    if (rawResults is! List) {
      throw const FormatException('Missing gallery search results.');
    }
    final items = <Artwork>[
      for (final raw in rawResults)
        if (raw is Map) WebDeviationMapper.mapDeviation(raw),
    ];
    final hasMore = data['hasMore'] == true;
    final nextOffset = data['nextOffset'];
    return Page<Artwork>(
      items: items,
      hasMore: hasMore,
      nextCursor: hasMore && nextOffset is int ? '$nextOffset' : null,
    );
  }
}
