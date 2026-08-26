import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'collection_contents.dart';
import 'html_state.dart';
import 'rfy_feed.dart';
import 'web_http.dart';

/// One page of a DeviantArt favourites collection.
final class CollectionContentsPage {
  const CollectionContentsPage({
    required this.items,
    required this.hasMore,
    this.coverUri,
  });

  final List<Artwork> items;
  final bool hasMore;

  /// The collection's own cover image (from its `thumb`), when available.
  final Uri? coverUri;
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
    int limit = 24,
  }) async {
    final response = await _dio.get<Object?>(
      _jsonEndpoint.toString(),
      queryParameters: <String, dynamic>{
        'username': username.toLowerCase(),
        'type': 'collection',
        'folderid': folderId,
        'offset': offset,
        'limit': limit,
        'mature_content': true,
        'csrf_token': csrfToken,
      },
      options: webSessionOptions(cookieHeader),
    );
    return parseJsonPage(response.data);
  }

  /// Fetches only the collection's cover image, using a single lightweight
  /// first page. Used as a fallback when the "More Like This" preview did not
  /// carry a collection cover.
  Future<Uri?> fetchCover({
    required int folderId,
    required String username,
    required String cookieHeader,
    required String csrfToken,
  }) async {
    final page = csrfToken.isNotEmpty
        ? await fetchJsonPage(
            folderId: folderId,
            username: username,
            cookieHeader: cookieHeader,
            csrfToken: csrfToken,
            limit: 1,
          )
        : await fetchPage(
            folderId: folderId,
            username: username,
            cookieHeader: cookieHeader,
            page: 1,
          );
    return page.coverUri;
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
  /// shared website deviation shape, mapped by [WebDeviationMapper.mapDeviation]),
  /// the `hasMore` flag, and the collection's own cover (`gallection.thumb`).
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
      final artwork = WebDeviationMapper.mapDeviation(
        Map<Object?, Object?>.from(raw),
      );
      if (artwork.id.isNotEmpty && artwork.media.isNotEmpty) {
        items.add(artwork);
      }
    }
    final gallection = data['gallection'];
    return CollectionContentsPage(
      items: List<Artwork>.unmodifiable(items),
      hasMore: data['hasMore'] == true,
      coverUri: _thumbImage(gallection is Map ? gallection['thumb'] : null),
    );
  }

  /// Extracts a folder page's deviations, `hasMore` flag, and the folder's own
  /// cover from its server-rendered `window.__INITIAL_STATE__`.
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
      Object? foldersResults;
      Object? folderDeviations;
      for (final module in modules.values) {
        if (module is! Map) continue;
        final moduleData = module['moduleData'];
        if (moduleData is! Map) continue;
        if (moduleData['folders'] is Map) {
          foldersResults = (moduleData['folders'] as Map)['results'];
        }
        if (moduleData['folderDeviations'] is Map) {
          folderDeviations = moduleData['folderDeviations'];
        }
      }
      if (folderDeviations is! Map) continue;
      final rawDeviations = folderDeviations['deviations'];
      if (rawDeviations is! List) continue;
      final items = <Artwork>[];
      for (final raw in rawDeviations) {
        if (raw is! Map) continue;
        final artwork = WebDeviationMapper.mapDeviation(
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
        coverUri: _folderCover(foldersResults, folderDeviations['folderId']),
      );
    }
    throw const FormatException('Missing DeviantArt folder deviations.');
  }

  /// The first image of a deviation-shaped `thumb` object, if any.
  static Uri? _thumbImage(Object? thumb) {
    if (thumb is! Map) return null;
    final artwork = WebDeviationMapper.mapDeviation(
      Map<Object?, Object?>.from(thumb),
    );
    for (final media in artwork.media) {
      if (media.kind == MediaKind.image && media.uri != null) {
        return media.uri;
      }
    }
    return null;
  }

  /// The cover of the folder whose id matches [targetFolderId] within the
  /// server-rendered `folders` module.
  static Uri? _folderCover(Object? foldersResults, Object? targetFolderId) {
    if (foldersResults is! List) return null;
    for (final folder in foldersResults) {
      if (folder is! Map) continue;
      if (targetFolderId != null && folder['folderId'] != targetFolderId) {
        continue;
      }
      final cover = _thumbImage(folder['thumb']);
      if (cover != null) return cover;
    }
    return null;
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
