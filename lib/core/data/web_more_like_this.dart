import 'dart:convert';

import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'html_state.dart';
import 'rfy_feed.dart';
import 'web_http.dart';

/// Reads the same related-artwork blocks that deviantart.com renders on an
/// artwork page.
///
/// DeviantArt's current website recommendations and the legacy OAuth
/// `browse/morelikethis/preview` response can diverge. The website embeds its
/// current `gallery` and `recommended` blocks, their normalized deviation
/// entities, and their normalized authors in `window.__INITIAL_STATE__`.
/// This fetcher restores those entities to the standard DAKit [Artwork] model
/// so the section remains fully native and related cards can open in-app.
final class WebMoreLikeThisFetcher {
  const WebMoreLikeThisFetcher(this._dio);

  final Dio _dio;

  Future<List<Artwork>> fetch({
    required Uri pageUri,
    required String deviationId,
    required String cookieHeader,
  }) async {
    if (pageUri.scheme != 'https' || !_isDeviantArtHost(pageUri.host)) {
      throw ArgumentError.value(pageUri, 'pageUri', 'Not a DeviantArt page.');
    }
    final response = await _dio.get<String>(
      pageUri.toString(),
      options: webPageOptions(cookieHeader),
    );
    final html = response.data;
    if (html == null || html.isEmpty) {
      throw const FormatException('Empty DeviantArt artwork page.');
    }
    return parseInitialState(html, deviationId: deviationId);
  }

  /// Parses a DeviantArt artwork page without executing any embedded script.
  /// Promoted (`boosted`) content and non-artwork blocks are deliberately
  /// excluded; only the site's organic `gallery` and `recommended` blocks are
  /// returned, in website order and without duplicates.
  static List<Artwork> parseInitialState(
    String html, {
    required String deviationId,
  }) {
    // DeviantArt's current server-rendered page streams related content into
    // a dedicated React cache after the initial state script. Prefer that
    // complete cache when present, while keeping the legacy normalized-state
    // parser below for older pages and rollout variants.
    if (html.contains('window.__RCACHE__ = JSON.parse(')) {
      try {
        return _parseRelatedCache(html, deviationId: deviationId);
      } on FormatException {
        // A partial streamed cache can coexist with a complete legacy state.
        // Fall through instead of making either website rollout exclusive.
      }
    }

    final state = _initialState(html);
    final entities = state['@@entities'];
    final duperbrowse = state['@@DUPERBROWSE'];
    if (entities is! Map || duperbrowse is! Map) {
      throw const FormatException('Missing DeviantArt recommendation state.');
    }
    final rawDeviations = entities['deviation'];
    final rawUsers = entities['user'];
    final metadataById = duperbrowse['currentBiMetadata'];
    if (rawDeviations is! Map || rawUsers is! Map || metadataById is! Map) {
      throw const FormatException(
        'Missing DeviantArt recommendation entities.',
      );
    }
    final metadataText =
        metadataById[deviationId] ?? metadataById[int.tryParse(deviationId)];
    if (metadataText is! String || metadataText.isEmpty) {
      // The browser can hydrate this block after the initial HTML arrives.
      // Missing metadata is therefore inconclusive, not proof that there are
      // no recommendations. Surface it so the caller can retry/fall back.
      throw const FormatException(
        'Missing recommendation metadata for this artwork.',
      );
    }
    final metadata = jsonDecode(metadataText);
    if (metadata is! List) {
      throw const FormatException('Unexpected recommendation metadata.');
    }

    final ids = <String>[];
    final seen = <String>{deviationId};
    for (final section in metadata) {
      if (section is! Map || section['type'] != 'relatedContent') continue;
      final blocks = section['blocks'];
      if (blocks is! List) continue;
      for (final block in blocks) {
        if (block is! Map) continue;
        final contentType = block['contentType'];
        if (contentType != 'gallery' && contentType != 'recommended') {
          continue;
        }
        final deviations = block['deviations'];
        if (deviations is! List) continue;
        for (final reference in deviations) {
          if (reference is! Map) continue;
          final rawId = reference['deviationid'] ?? reference['deviationId'];
          final id = rawId?.toString() ?? '';
          if (id.isNotEmpty && id != 'null' && seen.add(id)) ids.add(id);
        }
      }
    }

    final artworks = <Artwork>[];
    for (final id in ids) {
      final raw = rawDeviations[id] ?? rawDeviations[int.tryParse(id)];
      if (raw is! Map) continue;
      final deviation = Map<Object?, Object?>.from(raw);
      final authorReference = deviation['author'];
      if (authorReference is! Map) {
        final author =
            rawUsers[authorReference] ?? rawUsers[authorReference?.toString()];
        if (author is Map) deviation['author'] = author;
      }
      final artwork = RfyFeedFetcher.mapDeviation(deviation);
      if (artwork.id.isNotEmpty && artwork.media.isNotEmpty) {
        artworks.add(artwork);
      }
    }
    if (ids.isNotEmpty && artworks.isEmpty) {
      // References without their normalized entities are another partially
      // hydrated page state. Treating this as a real empty result hides website
      // recommendations that appear once the browser finishes loading.
      throw const FormatException(
        'Missing normalized recommendation entities.',
      );
    }
    return List<Artwork>.unmodifiable(artworks);
  }

  static List<Artwork> _parseRelatedCache(
    String html, {
    required String deviationId,
  }) {
    final cache = jsonParseAssignment(
      html,
      marker: 'window.__RCACHE__ = JSON.parse(',
      missingMessage: 'Missing DeviantArt related-content cache.',
    );
    final related = cache['relatedContent'];
    final sections = related is Map ? related['relatedContent'] : null;
    if (sections is! List) {
      throw const FormatException(
        'Missing DeviantArt related-content sections.',
      );
    }

    final seen = <String>{deviationId};
    final artworks = <Artwork>[];
    var referencedArtwork = false;
    for (final section in sections) {
      if (section is! Map) continue;
      final contentType = section['contentType'];
      if (contentType != 'gallery' && contentType != 'recommended') continue;
      final deviations = section['deviations'];
      if (deviations is! List) continue;
      for (final raw in deviations) {
        if (raw is! Map) continue;
        final rawId = raw['deviationId'] ?? raw['deviationid'];
        final id = rawId?.toString() ?? '';
        if (id.isEmpty || id == 'null' || id == deviationId) continue;
        referencedArtwork = true;
        if (!seen.add(id)) continue;
        final artwork = RfyFeedFetcher.mapDeviation(
          Map<Object?, Object?>.from(raw),
        );
        if (artwork.id.isNotEmpty && artwork.media.isNotEmpty) {
          artworks.add(artwork);
        }
      }
    }
    if (referencedArtwork && artworks.isEmpty) {
      throw const FormatException(
        'Missing media in DeviantArt related-content cache.',
      );
    }
    return List<Artwork>.unmodifiable(artworks);
  }

  static Map<Object?, Object?> _initialState(String html) {
    return jsonParseAssignment(
      html,
      marker: 'window.__INITIAL_STATE__ = JSON.parse(',
      missingMessage: 'Missing DeviantArt initial state.',
    );
  }

  static bool _isDeviantArtHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'deviantart.com' ||
        normalized.endsWith('.deviantart.com');
  }
}
