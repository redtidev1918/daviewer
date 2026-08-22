import 'package:dakit_core/dakit_core.dart';
import 'package:dio/dio.dart';

import 'web_http.dart';
import 'wix_media.dart';

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
///
/// Because this feed carries numeric deviation ids (which the OAuth API cannot
/// resolve), the mapped [Artwork] also carries the full-resolution image (and
/// video transcodes) directly, so the detail screen can render without an
/// OAuth round-trip.
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
      options: webSessionOptions(cookieHeader),
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
        items.add(mapDeviation(raw));
      }
    }
    return RfyPage(
      items: List<Artwork>.unmodifiable(items),
      nextCursor: data['nextCursor'] as String?,
    );
  }

  static Artwork mapDeviation(Map<Object?, Object?> json) {
    var id = '${json['deviationId']}';
    // Some feeds (user/profile/posts journals) don't carry `deviationId`;
    // fall back to the numeric id in the URL slug.
    if (id.isEmpty || id == 'null') {
      final url = json['url'];
      if (url is String) {
        final match = RegExp(r'-(\d+)/?$').firstMatch(url);
        if (match != null) id = match.group(1)!;
      }
    }
    final author = json['author'] as Map? ?? const <Object?, Object?>{};
    final username = author['username'] as String? ?? '';
    final media = json['media'] as Map? ?? const <Object?, Object?>{};
    final isDownloadable = json['isDownloadable'] == true;

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
      media: _mediaAssets(media, id, json),
      publishedAt: DateTime.tryParse(json['publishedTime'] as String? ?? ''),
      isMature: json['isMature'] == true,
      isDownloadable: isDownloadable,
      isFavourited: json['isFavourited'] == true,
      isMultiMedia: json['isMultiMedia'] == true,
      downloadAvailability: isDownloadable
          ? MediaAvailability.available
          : MediaAvailability.unavailable,
    );
  }

  /// Builds the media list for a deviation, carrying enough data for both the
  /// feed thumbnail and the detail screen (full image + playable video).
  static List<MediaAsset> _mediaAssets(
    Map<Object?, Object?> media,
    String id,
    Map<Object?, Object?> json,
  ) {
    final base = media['baseUri'] as String?;
    final pretty = media['prettyName'] as String? ?? '';
    final tokens = (media['token'] as List? ?? const <Object?>[])
        .whereType<String>()
        .toList(growable: false);
    final types = media['types'] as List? ?? const <Object?>[];
    final isVideo = json['isVideo'] == true || json['type'] == 'video';
    final filetype = json['filetype'] as String? ?? '';
    final isDownloadable = json['isDownloadable'] == true;

    final assets = <MediaAsset>[];

    // Thumbnail (~400px) for the feed grid. This also covers video posters.
    final posterUri = wixResampledUrl(
      base,
      pretty,
      tokens,
      types,
      targetWidth: 400,
    );
    if (posterUri != null) {
      assets.add(
        MediaAsset(
          id: '$id:preview',
          kind: MediaKind.image,
          role: MediaRole.preview,
          availability: MediaAvailability.available,
          uri: posterUri,
        ),
      );
    }

    if (isVideo) {
      // Video transcodes carry their own absolute URL in the `b` field (the
      // Wix `baseUri` is the poster, not the playable stream). Keep them in
      // ascending resolution so the viewer plays the smallest one first, and
      // flag the largest as the downloadable "original".
      final videos = <MediaAsset>[];
      for (final type in types) {
        if (type is! Map) continue;
        final url = type['b'];
        if (type['t'] != 'video' || url is! String || url.isEmpty) continue;
        final height = (type['h'] as num?)?.toInt() ?? 0;
        final seconds = (type['d'] as num?)?.toInt();
        videos.add(
          MediaAsset(
            id: '$id:video:$height',
            kind: MediaKind.video,
            role: MediaRole.preview,
            availability: MediaAvailability.available,
            uri: Uri.tryParse(withWixToken(url, type, tokens)),
            width: (type['w'] as num?)?.toInt(),
            height: height,
            duration: seconds == null ? null : Duration(seconds: seconds),
          ),
        );
      }
      videos.sort((a, b) => (a.height ?? 0).compareTo(b.height ?? 0));
      assets.addAll(videos);
      final largest = videos.isEmpty ? null : videos.last;
      if (largest != null) {
        assets.add(
          MediaAsset(
            id: '$id:original',
            kind: MediaKind.video,
            role: MediaRole.original,
            availability: isDownloadable
                ? MediaAvailability.available
                : MediaAvailability.unavailable,
            uri: largest.uri,
            width: largest.width,
            height: largest.height,
            filename: largest.uri == null
                ? null
                : _filenameFromUri(largest.uri!, pretty, filetype),
          ),
        );
      }
    } else if (base != null && base.isNotEmpty) {
      final isGif = filetype.toLowerCase() == 'gif';
      // Full-resolution file (animated GIF for `isGif`, otherwise the original
      // image) for download.
      final fullUri = Uri.tryParse(withWixToken(base, null, tokens));

      if (isGif) {
        // The resampled `types` for a GIF are static .jpg posters, so inline
        // display must use the animated `baseUri` (.gif) or the GIF never
        // animates.
        final gifType =
            wixTypeNamed(types, 'fullview') ?? wixLargestImageType(types);
        assets.add(
          MediaAsset(
            id: '$id:display',
            kind: MediaKind.image,
            role: MediaRole.preview,
            availability: MediaAvailability.available,
            uri: fullUri,
            mimeType: 'image/gif',
            width: (gifType?['w'] as num?)?.toInt(),
            height: (gifType?['h'] as num?)?.toInt(),
          ),
        );
      } else {
        // A display-size image (~largest resampled transform) for inline detail
        // rendering. The raw `baseUri` can be an enormous original (e.g. 8K),
        // which is heavy to decode inline — so it is reserved for download.
        final display = wixLargestImageType(types);
        final displayUri = wixResampledUrl(base, pretty, tokens, types);
        if (displayUri != null) {
          assets.add(
            MediaAsset(
              id: '$id:display',
              kind: MediaKind.image,
              role: MediaRole.preview,
              availability: MediaAvailability.available,
              uri: displayUri,
              width: (display?['w'] as num?)?.toInt(),
              height: (display?['h'] as num?)?.toInt(),
            ),
          );
        }
      }

      assets.add(
        MediaAsset(
          id: '$id:original',
          kind: MediaKind.image,
          role: MediaRole.original,
          availability: isDownloadable
              ? MediaAvailability.available
              : MediaAvailability.unavailable,
          uri: fullUri,
          mimeType: _mimeType(filetype),
          filename: fullUri == null
              ? null
              : _filenameFromUri(fullUri, pretty, filetype),
        ),
      );
    }

    return List<MediaAsset>.unmodifiable(assets);
  }

  static String _filenameFromUri(Uri uri, String pretty, String filetype) {
    final segments = uri.pathSegments;
    final last = segments.isNotEmpty ? segments.last : '';
    if (last.isNotEmpty && last.contains('.')) return last;
    final base = pretty.isEmpty ? 'artwork' : pretty;
    final ext = filetype.isEmpty ? 'bin' : filetype;
    return '$base.$ext';
  }

  static String? _mimeType(String filetype) {
    switch (filetype.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'avif':
        return 'image/avif';
      default:
        return null;
    }
  }

  static Uri? _uri(Object? value) {
    final text = value is String ? value : null;
    if (text == null || text.isEmpty) return null;
    return Uri.tryParse(text);
  }
}
