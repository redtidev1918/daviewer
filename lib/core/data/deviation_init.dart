import 'package:dio/dio.dart';

/// Result of the web `dadeviation/init` endpoint: the OAuth UUID for a numeric
/// deviation id plus the full rich-text description markup.
final class DeviationInit {
  const DeviationInit({required this.uuid, required this.descriptionHtml});

  final String uuid;
  final String? descriptionHtml;
}

/// Resolves a numeric deviation id (the id used by the personalized `rfy`
/// feed) to the OAuth UUID and author description.
///
/// The official OAuth API only accepts UUIDs (`deviation/{uuid}`), while the
/// web feed uses numeric ids. This private web endpoint bridges the two and
/// also carries the full description (`descriptionText.html.markup`) that the
/// official API no longer returns. It is authenticated with the embedded
/// WebView's web session (Cookie + CSRF), so it must be used with those.
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
    return DeviationInit(uuid: uuid, descriptionHtml: _clean(markup));
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
