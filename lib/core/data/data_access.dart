import 'package:dakit_flutter/dakit_flutter.dart';

import '../runtime/app_runtime.dart';

/// Routes data requests to the official API repositories. Web-scraping
/// fallbacks (e.g. `dadeviation/init` for descriptions) live in their own
/// fetchers under `core/data`.
final class DataAccess {
  const DataAccess({required this.runtime});

  final AppRuntime runtime;

  Future<Page<Artwork>> search(String query, PageRequest request) =>
      OfficialArtworkRepository(runtime.transport!).search(query, request);

  Future<Page<Artwork>> gallery(String username, PageRequest request) =>
      OfficialGalleryRepository(runtime.transport!).gallery(username, request);

  Future<Page<Artwork>> favourites(String username, PageRequest request) =>
      OfficialGalleryRepository(runtime.transport!)
          .favourites(username, request);

  Future<UserProfileDetails> profile(String username) =>
      OfficialUserRepository(runtime.transport!).profile(username);

  Future<Artwork> artworkById(String id) =>
      OfficialArtworkRepository(runtime.transport!).getById(id);

  /// Fetches searchable tags from DeviantArt's dedicated metadata endpoint.
  ///
  /// Compact list responses (notably `browse/deviantsyouwatch`) omit tags, and
  /// `deviation/{id}` does not reliably add them back. The metadata endpoint is
  /// the canonical source for this field.
  Future<List<String>> artworkTags(String id) =>
      OfficialArtworkMetadataRepository(runtime.transport!).tags(id);

  Future<MediaAsset> originalFile(String artworkId) =>
      OfficialMediaRepository(runtime.transport!).originalFile(artworkId);
}

/// Convenience: build a [DataAccess] from the runtime.
DataAccess dataAccessFor(AppRuntime runtime) => DataAccess(runtime: runtime);
