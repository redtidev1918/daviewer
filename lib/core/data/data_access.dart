import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';

import '../runtime/app_runtime.dart';

/// Routes data requests to the official API repositories plus web-scraping
/// fallbacks for fields the official API no longer exposes.
final class DataAccess {
  const DataAccess({required this.runtime});

  final AppRuntime runtime;

  Future<Page<Artwork>> browse(PageRequest request) =>
      OfficialArtworkRepository(runtime.transport!).browse(request);

  Future<Page<Artwork>> search(String query, PageRequest request) =>
      OfficialArtworkRepository(runtime.transport!).search(query, request);

  Future<Page<Artwork>> gallery(String username, PageRequest request) =>
      OfficialGalleryRepository(runtime.transport!).gallery(username, request);

  Future<Page<Artwork>> favourites(String username, PageRequest request) =>
      OfficialGalleryRepository(runtime.transport!).favourites(username, request);

  Future<UserProfileDetails> profile(String username) =>
      OfficialUserRepository(runtime.transport!).profile(username);

  Future<Artwork> artworkById(String id) =>
      OfficialArtworkRepository(runtime.transport!).getById(id);

  Future<MediaAsset> originalFile(String artworkId) =>
      OfficialMediaRepository(runtime.transport!).originalFile(artworkId);

  /// Fetches the artwork description from the public web page's
  /// `og:description` meta tag. The official API no longer returns author
  /// descriptions, so this is the reliable source.
  Future<String?> artworkDescription(Artwork artwork) async {
    final dio = runtime.dio;
    if (dio == null) return artwork.description;
    final pageUri = artwork.pageUri;
    try {
      final response = await dio.get<String>(
        pageUri.toString(),
        options: Options(
          responseType: ResponseType.plain,
          headers: const <String, String>{
            'user-agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
                'AppleWebKit/537.36 Chrome/126.0 Safari/537.36',
          },
        ),
      );
      final html = response.data ?? '';
      final match = RegExp(
        '<meta[^>]+property=["\']og:description["\'][^>]+content=["\']([^"\']+)["\']',
      ).firstMatch(html);
      if (match == null) return artwork.description;
      var description = match.group(1)!;
      // Decode common HTML entities.
      description = description
          .replaceAll('&#x27;', "'")
          .replaceAll('&#39;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>');
      // Strip the boilerplate suffix ("— artwork by X on DeviantArt").
      final separator = description.indexOf(' — ');
      if (separator > 0) {
        description = description.substring(0, separator);
      }
      final trimmed = description.trim();
      return trimmed.isEmpty ? artwork.description : trimmed;
    } on Object {
      return artwork.description;
    }
  }
}

/// Convenience: build a [DataAccess] from the runtime.
DataAccess dataAccessFor(AppRuntime runtime) => DataAccess(runtime: runtime);
