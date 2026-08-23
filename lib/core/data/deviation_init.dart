import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'html_text.dart';
import 'web_http.dart';
import 'wix_media.dart';

/// Result of the web `dadeviation/init` endpoint: the OAuth UUID for a numeric
/// deviation id plus the full description as plain text and any additional
/// multi-image pages.
final class DeviationInit {
  const DeviationInit({
    required this.uuid,
    required this.description,
    this.descriptionHtml,
    this.additionalMedia = const <MediaAsset>[],
    this.tags = const <String>[],
  });

  final String uuid;

  /// The author description, already converted to plain text.
  final String? description;

  /// The author description as an HTML fragment (preserving links/formatting),
  /// when the provider supplied a renderable markup.
  final String? descriptionHtml;

  /// Display-size assets for each additional page of a multi-image deviation.
  final List<MediaAsset> additionalMedia;

  /// Searchable tag names attached to the deviation.
  final List<String> tags;
}

/// Resolves a numeric deviation id (the id used by the personalized `rfy`
/// feed) to the OAuth UUID, the author description, and multi-image pages.
///
/// The official OAuth API only accepts UUIDs (`deviation/{uuid}`), while the
/// web feed uses numeric ids. This private web endpoint bridges the two and
/// also carries the full description (`descriptionText.html.markup`) and the
/// `extended.additionalMedia` pages that the official API no longer returns. It
/// is authenticated with the embedded WebView's web session (Cookie + CSRF).
final class DeviationInitFetcher {
  const DeviationInitFetcher(this._dio);

  final Dio _dio;

  static final Uri _endpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dadeviation/init',
  );

  Future<DeviationInit> fetch({
    required String deviationId,
    required String username,
    required String cookieHeader,
    required String csrfToken,
  }) async {
    final response = await _dio.get<Object?>(
      _endpoint.toString(),
      queryParameters: <String, dynamic>{
        'deviationid': deviationId,
        'username': username,
        'type': 'art',
        'include_session': false,
        'csrf_token': csrfToken,
      },
      options: webSessionOptions(cookieHeader),
    );
    return parseInit(response.data);
  }

  /// Parses a `dadeviation/init` response body into a [DeviationInit]. Extracted
  /// from [fetch] so the parser is unit-testable against a captured snapshot
  /// without a live web session.
  static DeviationInit parseInit(Object? data) {
    if (data is! Map) {
      throw const FormatException('Unexpected deviation init shape.');
    }
    final deviation = data['deviation'];
    if (deviation is! Map) {
      throw const FormatException('Missing deviation in init response.');
    }
    final deviationId = '${deviation['deviationId'] ?? ''}';
    final extended = deviation['extended'];
    final uuid = extended is Map ? extended['deviationUuid'] as String? : null;
    if (uuid == null || uuid.isEmpty) {
      throw const FormatException('Missing deviationUuid in init response.');
    }
    final descriptionText = extended is Map
        ? extended['descriptionText']
        : null;
    final html = descriptionText is Map ? descriptionText['html'] : null;
    final type = html is Map ? html['type'] : null;
    final markup = html is Map ? html['markup'] as String? : null;
    // `markup` is HTML for `writer`-type descriptions and a tiptap JSON string
    // for `tiptap`-type descriptions; keep both a plain-text and an HTML form.
    String? description;
    String? descriptionHtml;
    if (markup != null && markup.trim().isNotEmpty) {
      description = type == 'tiptap'
          ? tiptapToPlainText(markup)
          : htmlToPlainText(markup);
      if (description.isEmpty) description = null;
      descriptionHtml = type == 'tiptap' ? tiptapToHtml(markup) : markup;
      if (descriptionHtml.trim().isEmpty) {
        descriptionHtml = null;
      }
    }

    final rawAdditional = extended is Map ? extended['additionalMedia'] : null;
    final additional = <MediaAsset>[];
    if (rawAdditional is List) {
      for (var index = 0; index < rawAdditional.length; index++) {
        final item = rawAdditional[index];
        // Each additional-media entry nests its Wix descriptor under `media`.
        final media = item is Map ? item['media'] : null;
        if (media is! Map) continue;
        final asset = _displayAsset(media, '$deviationId:page:${index + 1}');
        if (asset != null) additional.add(asset);
      }
    }

    final rawTags = extended is Map ? extended['tags'] : null;
    final tags = <String>[];
    if (rawTags is List) {
      for (final tag in rawTags) {
        if (tag is Map) {
          final name = tag['name'];
          if (name is String && name.isNotEmpty) tags.add(name);
        }
      }
    }

    return DeviationInit(
      uuid: uuid,
      description: description,
      descriptionHtml: descriptionHtml,
      additionalMedia: List<MediaAsset>.unmodifiable(additional),
      tags: List<String>.unmodifiable(tags),
    );
  }

  /// Builds a single display-size [MediaAsset] for a Wix media descriptor:
  /// the largest resampled image transform, or the raw baseUri for animated
  /// GIFs (whose resampled `types` are static .jpg posters).
  static MediaAsset? _displayAsset(Map<Object?, Object?> media, String id) {
    final base = media['baseUri'] as String?;
    final pretty = media['prettyName'] as String? ?? '';
    final filetype = media['filetype'] as String? ?? '';
    final tokens = (media['token'] as List? ?? const <Object?>[])
        .whereType<String>()
        .toList(growable: false);
    final types = media['types'] as List? ?? const <Object?>[];
    if (base == null || base.isEmpty) return null;

    final isGif =
        filetype.toLowerCase() == 'gif' || base.toLowerCase().endsWith('.gif');
    final uri = isGif
        ? Uri.tryParse(withWixToken(base, null, tokens))
        : wixResampledUrl(base, pretty, tokens, types);
    if (uri == null) return null;
    return MediaAsset(
      id: id,
      kind: MediaKind.image,
      role: MediaRole.preview,
      availability: MediaAvailability.available,
      uri: uri,
      mimeType: isGif ? 'image/gif' : null,
    );
  }
}

/// Fetches the full rich-text body of a journal (literature) deviation from the
/// web `dadeviation/init` endpoint (`type=journal`). The official API only
/// exposes a truncated plain-text excerpt for journals; the embedded images and
/// inline formatting live in a web-only tiptap document.
final class JournalContentFetcher {
  const JournalContentFetcher(this._dio);

  final Dio _dio;

  static final Uri _endpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dadeviation/init',
  );

  Future<String?> fetchHtml({
    required String deviationId,
    required String username,
    required String cookieHeader,
    required String csrfToken,
  }) async {
    final response = await _dio.get<Object?>(
      _endpoint.toString(),
      queryParameters: <String, dynamic>{
        'deviationid': deviationId,
        'username': username,
        'type': 'journal',
        'include_session': false,
        'csrf_token': csrfToken,
      },
      options: webSessionOptions(cookieHeader),
    );
    final data = response.data;
    if (data is! Map) return null;
    final deviation = data['deviation'];
    if (deviation is! Map) return null;
    final textContent = deviation['textContent'];
    final html = textContent is Map ? textContent['html'] : null;
    final type = html is Map ? html['type'] : null;
    final markup = html is Map ? html['markup'] as String? : null;
    if (markup == null || markup.trim().isEmpty) return null;
    return type == 'tiptap' ? tiptapToHtml(markup) : markup;
  }
}
