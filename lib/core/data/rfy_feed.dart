import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

/// One page of the DeviantArt web `rfy/deviations` personalized feed.
final class RfyPage {
  const RfyPage({required this.items, required this.nextCursor});

  final List<Artwork> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null && nextCursor!.isNotEmpty;
}

/// Fetches the web `rfy/deviations` personalized feed using the embedded
/// WebView's web session (Cookie + CSRF token), and maps it back to the
/// standard DAKit [Artwork] model so it renders through the native feed UI.
///
/// The official OAuth API does not expose this personalized feed; it is the
/// private web endpoint behind deviantart.com's home page, authenticated with
/// the browser Cookie and the page's `csrf_token` (sent as a query parameter).
final class RfyFeedFetcher {
  const RfyFeedFetcher(this._dio);

  final Dio _dio;

  static final Uri _endpoint = Uri.parse(
    'https://www.deviantart.com/_puppy/dabrowse/networkbar/rfy/deviations',
  );

  Future<RfyPage> fetch({
    required String cookieHeader,
    required String csrfToken,
    String? cursor,
  }) async {
    final response = await _dio.get<Object?>(
      _endpoint.toString(),
      queryParameters: <String, dynamic>{
        'csrf_token': csrfToken,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
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
      throw const FormatException('Unexpected rfy response shape.');
    }
    final rawDeviations = data['deviations'];
    if (rawDeviations is! List) {
      throw const FormatException('Missing deviations list.');
    }
    final items = <Artwork>[];
    for (final raw in rawDeviations) {
      if (raw is Map) {
        items.add(_mapDeviation(raw));
      }
    }
    return RfyPage(
      items: List<Artwork>.unmodifiable(items),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  static Artwork _mapDeviation(Map<Object?, Object?> json) {
    final id = '${json['deviationId']}';
    final author = json['author'] as Map? ?? const <Object?, Object?>{};
    final username = author['username'] as String? ?? '';
    final media = json['media'] as Map? ?? const <Object?, Object?>{};
    final previewUri = _imageUri(media);

    return Artwork(
      id: id,
      title: json['title'] as String? ?? '',
      author: UserProfile(
        id: '${author['userId'] ?? ''}',
        username: username,
        displayName: username.isEmpty ? null : username,
        avatarUri: _uri(author['usericon']),
        profileUri: Uri.https('www.deviantart.com', '/$username'),
      ),
      pageUri: _uri(json['url']) ?? Uri.https('www.deviantart.com'),
      media: <MediaAsset>[
        if (previewUri != null)
          MediaAsset(
            id: '$id:preview',
            kind: MediaKind.image,
            role: MediaRole.preview,
            availability: MediaAvailability.available,
            uri: previewUri,
          ),
      ],
      publishedAt: DateTime.tryParse(json['publishedTime'] as String? ?? ''),
      isMature: json['isMature'] == true,
      isDownloadable: json['isDownloadable'] == true,
    );
  }

  /// Builds a feed-thumbnail URL from the Wix media descriptor:
  /// `baseUri + <transform>?token=<jwt>`, choosing the size closest to 400px
  /// wide. The transform template substitutes the `<prettyName>` placeholder.
  static Uri? _imageUri(Map<Object?, Object?> media) {
    final base = media['baseUri'] as String?;
    final pretty = media['prettyName'] as String? ?? '';
    final tokens = media['token'] as List? ?? const <Object?>[];
    final types = media['types'] as List? ?? const <Object?>[];
    if (base == null || tokens.isEmpty || types.isEmpty) return null;

    Map<Object?, Object?>? best;
    var bestDelta = 1 << 30;
    for (final type in types) {
      if (type is! Map) continue;
      final width = (type['w'] as num?)?.toInt() ?? 0;
      final delta = (width - 400).abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        best = type;
      }
    }
    if (best == null) return null;

    final transform =
        (best['c'] as String? ?? '').replaceAll('<prettyName>', pretty);
    return Uri.tryParse('$base$transform?token=${tokens.first}');
  }

  static Uri? _uri(Object? value) {
    final text = value is String ? value : null;
    if (text == null || text.isEmpty) return null;
    return Uri.tryParse(text);
  }

  static const String _userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
      'AppleWebKit/537.36 Chrome/126.0 Safari/537.36';
}
