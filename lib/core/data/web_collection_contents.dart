import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'collection_contents.dart';
import 'html_state.dart';
import 'rfy_feed.dart';
import 'web_http.dart';

/// One page of a DeviantArt favourites collection.
final class CollectionContentsPage {
  const CollectionContentsPage({required this.items, required this.hasMore});

  final List<Artwork> items;
  final bool hasMore;
}

/// Fetches the full contents of a public DeviantArt favourites collection given
/// its numeric web `folderId`.
///
/// The official OAuth API only accepts a UUID `folderid` for `collections/…`,
/// while the "More Like This" preview only exposes the numeric id
/// (`CollectionSummary.folderId`). There is no official numeric-id path, so this
/// fetcher reads the same private `gallection/contents` endpoint the website
/// uses (`_puppy/dashared/gallection/contents`), which returns clean JSON and is
/// far lighter than the server-rendered page.
///
/// That endpoint needs a web-session Cookie + CSRF token (an anonymous
/// deviantart.com visit also supplies both). When no session is available, it
/// falls back to the server-rendered favourites page
/// (`deviantart.com/{username}/favourites/{folderId}?page=N`), whose
/// `window.__INITIAL_STATE__` embeds the same deviation shape.
final class WebCollectionContentsFetcher {
  const WebCollectionContentsFetcher(this._dio);

  final Dio _dio;

  static final Uri _jsonEndpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dashared/gallection/contents',
  );

  /// Fetches one page via the lightweight `gallection/contents` JSON endpoint.
  Future<CollectionContentsPage> fetchJsonPage({
    required int folderId,
    required String username,
    required String cookieHeader,
    required String csrfToken,
    int offset = 0,
  }) async {
    final response = await _dio.get<Object?>(
      _jsonEndpoint.toString(),
      queryParameters: <String, dynamic>{
        'username': username.toLowerCase(),
        'type': 'collection',
        'folderid': folderId,
        'offset': offset,
        'limit': 24,
        'mature_content': true,
        'csrf_token': csrfToken,
      },
      options: webSessionOptions(cookieHeader),
    );
    return parseJsonPage(response.data);
  }

  /// Fetches every page through the JSON endpoint (offset pagination).
  Future<List<Artwork>> fetchAllJson({
    required int folderId,
    required String username,
    required String cookieHeader,
    required String csrfToken,
  }) async {
    final all = <Artwork>[];
    var offset = 0;
    while (offset < 20000) {
      final result = await fetchJsonPage(
        folderId: folderId,
        username: username,
        cookieHeader: cookieHeader,
        csrfToken: csrfToken,
        offset: offset,
      );
      all.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) break;
      offset += 24;
    }
    return List<Artwork>.unmodifiable(all);
  }

  /// Fetches one page via the server-rendered favourites page (session-free).
  Future<CollectionContentsPage> fetchPage({
    required int folderId,
    required String username,
    required String cookieHeader,
    int page = 1,
  }) async {
    final uri = Uri.https(
      'www.deviantart.com',
      '/${username.toLowerCase()}/favourites/$folderId',
      <String, String>{'page': '$page'},
    );
    final response = await _dio.get<String>(
      uri.toString(),
      options: webPageOptions(cookieHeader),
    );
    final html = response.data;
    if (html == null || html.isEmpty) {
      throw const FormatException('Empty DeviantArt collection page.');
    }
    return parsePage(html);
  }

  /// Fetches every page through the server-rendered page, in website order. A
  /// safety cap keeps a malformed `hasMore` from looping forever.
  Future<List<Artwork>> fetchAll({
    required int folderId,
    required String username,
    required String cookieHeader,
  }) async {
    final all = <Artwork>[];
    var page = 1;
    while (page <= 200) {
      final result = await fetchPage(
        folderId: folderId,
        username: username,
        cookieHeader: cookieHeader,
        page: page,
      );
      all.addAll(result.items);
      if (!result.hasMore || result.items.isEmpty) break;
      page++;
    }
    return List<Artwork>.unmodifiable(all);
  }

  /// Parses a `gallection/contents` JSON response: `results` (the same web
  /// deviation shape as the `rfy` feed, mapped by [RfyFeedFetcher.mapDeviation])
  /// plus the `hasMore` flag.
  static CollectionContentsPage parseJsonPage(Object? data) {
    if (data is! Map) {
      throw const FormatException('Unexpected collection contents shape.');
    }
    final rawResults = data['results'];
    if (rawResults is! List) {
      throw const FormatException('Missing collection results.');
    }
    final items = <Artwork>[];
    for (final raw in rawResults) {
      if (raw is! Map) continue;
      final artwork = RfyFeedFetcher.mapDeviation(
        Map<Object?, Object?>.from(raw),
      );
      if (artwork.id.isNotEmpty && artwork.media.isNotEmpty) {
        items.add(artwork);
      }
    }
    return CollectionContentsPage(
      items: List<Artwork>.unmodifiable(items),
      hasMore: data['hasMore'] == true,
    );
  }

  /// Extracts a folder page's deviations and `hasMore` flag from its
  /// server-rendered `window.__INITIAL_STATE__`.
  static CollectionContentsPage parsePage(String html) {
    final state = jsonParseAssignment(
      html,
      marker: 'window.__INITIAL_STATE__ = JSON.parse(',
      missingMessage: 'Missing DeviantArt initial state.',
    );
    final gruser = state['@@gruser'];
    final grusers = gruser is Map ? gruser['grusers'] : null;
    if (grusers is! Map) {
      throw const FormatException('Missing DeviantArt grusers state.');
    }
    for (final entry in grusers.values) {
      if (entry is! Map) continue;
      final modules = entry['modules'];
      if (modules is! Map) continue;
      for (final module in modules.values) {
        if (module is! Map) continue;
        final moduleData = module['moduleData'];
        if (moduleData is! Map) continue;
        final folderDeviations = moduleData['folderDeviations'];
        if (folderDeviations is! Map) continue;
        final rawDeviations = folderDeviations['deviations'];
        if (rawDeviations is! List) continue;
        final items = <Artwork>[];
        for (final raw in rawDeviations) {
          if (raw is! Map) continue;
          final artwork = RfyFeedFetcher.mapDeviation(
            Map<Object?, Object?>.from(raw),
          );
          // Journals and other media-less entries have no thumbnail to render
          // in the image grid, mirroring the related-content filter.
          if (artwork.id.isNotEmpty && artwork.media.isNotEmpty) {
            items.add(artwork);
          }
        }
        return CollectionContentsPage(
          items: List<Artwork>.unmodifiable(items),
          hasMore: folderDeviations['hasMore'] == true,
        );
      }
    }
    throw const FormatException('Missing DeviantArt folder deviations.');
  }
}

/// The web implementation of [CollectionContentsSource]. Kept behind the
/// interface so a future official (UUID-based) implementation can replace it
/// without touching the collection UI.
final class WebCollectionContentsSource implements CollectionContentsSource {
  const WebCollectionContentsSource(
    this._dio, {
    required this.cookieHeader,
    required this.csrfToken,
  });

  final Dio _dio;
  final String cookieHeader;
  final String csrfToken;

  @override
  Future<List<Artwork>> contents(int folderId, String username) {
    final fetcher = WebCollectionContentsFetcher(_dio);
    // Prefer the lightweight JSON endpoint when a web session (Cookie + CSRF)
    // is available; fall back to the session-free server-rendered page.
    if (csrfToken.isNotEmpty) {
      return fetcher.fetchAllJson(
        folderId: folderId,
        username: username,
        cookieHeader: cookieHeader,
        csrfToken: csrfToken,
      );
    }
    return fetcher.fetchAll(
      folderId: folderId,
      username: username,
      cookieHeader: cookieHeader,
    );
  }
}
