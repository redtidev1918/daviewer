import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

/// Result of the web `dadeviation/init` endpoint: the OAuth UUID for a numeric
/// deviation id plus the full rich-text description markup and any additional
/// multi-image pages.
final class DeviationInit {
  const DeviationInit({
    required this.uuid,
    required this.descriptionHtml,
    this.additionalMedia = const <MediaAsset>[],
  });

  final String uuid;
  final String? descriptionHtml;

  /// Display-size assets for each additional page of a multi-image deviation.
  final List<MediaAsset> additionalMedia;
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
      options: Options(
        responseType: ResponseType.json,
        headers: <String, dynamic>{
          'Accept': 'application/json',
          'Cookie': cookieHeader,
          'User-Agent': _userAgent,
        },
      ),
    );
    final data = response.data;
    if (data is! Map) {
      throw const FormatException('Unexpected deviation init shape.');
    }
    final deviation = data['deviation'];
    if (deviation is! Map) {
      throw const FormatException('Missing deviation in init response.');
    }
    final extended = deviation['extended'];
    final uuid = extended is Map ? extended['deviationUuid'] as String? : null;
    if (uuid == null || uuid.isEmpty) {
      throw const FormatException('Missing deviationUuid in init response.');
    }
    final descriptionText = extended is Map
        ? extended['descriptionText']
        : null;
    final html = descriptionText is Map ? descriptionText['html'] : null;
    final markup = html is Map ? html['markup'] as String? : null;

    final rawAdditional = extended is Map ? extended['additionalMedia'] : null;
    final additional = <MediaAsset>[];
    if (rawAdditional is List) {
      for (var index = 0; index < rawAdditional.length; index++) {
        final media = rawAdditional[index];
        if (media is! Map) continue;
        final asset = _displayAsset(media, '$deviationId:page:${index + 1}');
        if (asset != null) additional.add(asset);
      }
    }

    return DeviationInit(
      uuid: uuid,
      descriptionHtml: _clean(markup),
      additionalMedia: List<MediaAsset>.unmodifiable(additional),
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

    final isGif = filetype.toLowerCase() == 'gif';
    Uri? uri;
    if (isGif) {
      uri = Uri.tryParse(_withToken(base, null, tokens));
    } else {
      Map<Object?, Object?>? best;
      var bestWidth = -1;
      for (final type in types) {
        if (type is! Map) continue;
        final transform = type['c'];
        if (transform is! String || transform.isEmpty) continue;
        final width = (type['w'] as num?)?.toInt() ?? 0;
        if (width > bestWidth) {
          bestWidth = width;
          best = type;
        }
      }
      if (best == null) {
        uri = Uri.tryParse(_withToken(base, null, tokens));
      } else {
        final transform = (best['c'] as String).replaceAll('<prettyName>', pretty);
        uri = Uri.tryParse(_withToken('$base$transform', best, tokens));
      }
    }
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

  static String _withToken(String url, Map<Object?, Object?>? type, List<String> tokens) {
    if (tokens.isEmpty) return url;
    final index = type?['r'];
    final token = index is int && index >= 0 && index < tokens.length
        ? tokens[index]
        : tokens.first;
    if (token.isEmpty) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}token=$token';
  }

  static String? _clean(String? markup) {
    if (markup == null) return null;
    final trimmed = markup.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
}
