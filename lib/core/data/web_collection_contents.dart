import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'collection_contents.dart';
import 'html_state.dart';
import 'rfy_feed.dart';
import 'web_http.dart';

/// One page of a DeviantArt favourites collection, read from the
/// server-rendered folder page.
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
/// (`CollectionSummary.folderId`). There is no official numeric-id path, so
/// this fetcher reads the same data the website itself renders: the
/// `deviantart.com/{username}/favourites/{folderId}?page=N` page embeds the
/// folder's deviations (full Wix media descriptors) in `window.__INITIAL_STATE__`.
///
/// These favourites folder pages are public, so no web session is required; the
/// optional [cookieHeader] is forwarded for consistency with the other web
/// fetchers and for any folder gated behind a login.
final class WebCollectionContentsFetcher {
  const WebCollectionContentsFetcher(this._dio);

  final Dio _dio;

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

  /// Fetches every page of the collection, in website order. A safety cap
  /// keeps a malformed `hasMore` from looping forever.
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

  /// Extracts a folder page's deviations and `hasMore` flag from its
  /// server-rendered `window.__INITIAL_STATE__`, mapping them back to the
  /// standard DAKit [Artwork] model (same web deviation shape as the `rfy`
  /// feed, so [RfyFeedFetcher.mapDeviation] is reused).
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

/// The web-scraping implementation of [CollectionContentsSource]. Kept behind
/// the interface so a future official (UUID-based) implementation can replace
/// it without touching the collection UI.
final class WebCollectionContentsSource implements CollectionContentsSource {
  const WebCollectionContentsSource(this._dio, {required this.cookieHeader});

  final Dio _dio;
  final String cookieHeader;

  @override
  Future<List<Artwork>> contents(int folderId, String username) {
    return WebCollectionContentsFetcher(_dio).fetchAll(
      folderId: folderId,
      username: username,
      cookieHeader: cookieHeader,
    );
  }
}
