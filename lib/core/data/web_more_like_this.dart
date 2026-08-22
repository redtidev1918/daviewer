import 'dart:convert';

import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

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
      return const <Artwork>[];
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
    return List<Artwork>.unmodifiable(artworks);
  }

  static Map<Object?, Object?> _initialState(String html) {
    const marker = 'window.__INITIAL_STATE__ = JSON.parse(';
    final markerIndex = html.indexOf(marker);
    if (markerIndex < 0) {
      throw const FormatException('Missing DeviantArt initial state.');
    }
    final literalStart = markerIndex + marker.length;
    final decoded = _decodeJavaScriptString(html, literalStart);
    final state = jsonDecode(decoded);
    if (state is! Map) {
      throw const FormatException('Unexpected DeviantArt initial state.');
    }
    return state;
  }

  /// Decodes one JavaScript string literal. DeviantArt currently emits `\'`
  /// inside a double-quoted literal, which is valid JavaScript but invalid JSON,
  /// so feeding the outer literal directly to [jsonDecode] is not sufficient.
  /// No code is evaluated here.
  static String _decodeJavaScriptString(String source, int start) {
    if (start >= source.length ||
        (source.codeUnitAt(start) != 0x22 &&
            source.codeUnitAt(start) != 0x27)) {
      throw const FormatException('Missing initial-state string literal.');
    }
    final quote = source.codeUnitAt(start);
    final result = StringBuffer();
    var index = start + 1;
    while (index < source.length) {
      final code = source.codeUnitAt(index++);
      if (code == quote) return result.toString();
      if (code != 0x5c) {
        result.writeCharCode(code);
        continue;
      }
      if (index >= source.length) break;
      final escaped = source.codeUnitAt(index++);
      switch (escaped) {
        case 0x62: // b
          result.writeCharCode(0x08);
        case 0x66: // f
          result.writeCharCode(0x0c);
        case 0x6e: // n
          result.writeCharCode(0x0a);
        case 0x72: // r
          result.writeCharCode(0x0d);
        case 0x74: // t
          result.writeCharCode(0x09);
        case 0x76: // v
          result.writeCharCode(0x0b);
        case 0x0a: // JavaScript line continuation
          break;
        case 0x0d:
          if (index < source.length && source.codeUnitAt(index) == 0x0a) {
            index++;
          }
        case 0x78: // xNN
          result.writeCharCode(_hexEscape(source, index, 2));
          index += 2;
        case 0x75: // uNNNN
          result.writeCharCode(_hexEscape(source, index, 4));
          index += 4;
        default:
          // Includes escaped quote, apostrophe, slash, and backslash. JS also
          // permits identity escapes; preserving the escaped character matches
          // browser string-literal semantics for this data container.
          result.writeCharCode(escaped);
      }
    }
    throw const FormatException('Unterminated initial-state string literal.');
  }

  static int _hexEscape(String source, int start, int length) {
    if (start + length > source.length) {
      throw const FormatException('Truncated initial-state escape.');
    }
    final value = int.tryParse(
      source.substring(start, start + length),
      radix: 16,
    );
    if (value == null) {
      throw const FormatException('Invalid initial-state escape.');
    }
    return value;
  }

  static bool _isDeviantArtHost(String host) {
    final normalized = host.toLowerCase();
    return normalized == 'deviantart.com' ||
        normalized.endsWith('.deviantart.com');
  }
}
