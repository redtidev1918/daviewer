import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/data/rfy_feed.dart';
import '../../core/feed/artwork_feed_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final artistProfileProvider = FutureProvider.autoDispose
    .family<UserProfileDetails, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).profile(username);
    });

final artistGalleryProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, username) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).gallery(username, request);
      });
      return controller;
    });

final artistFavouritesProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, String>((ref, username) {
      final controller = ArtworkFeedController((request) {
        final runtime = ref.read(runtimeProvider);
        return dataAccessFor(runtime).favourites(username, request);
      });
      return controller;
    });

/// The artist's custom gallery folders (sub-galleries).
final artistFoldersProvider = FutureProvider.autoDispose
    .family<List<ArtworkFolder>, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      final page = await OfficialFolderRepository(
        runtime.transport!,
      ).galleryFolders(username: username);
      return page.items;
    });

/// The artist's journal posts (articles), via the official
/// `user/profile/posts` endpoint filtered to `/journal/` entries.
final artistJournalsProvider = FutureProvider.autoDispose
    .family<List<Artwork>, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      final json = await runtime.transport!.getJson(
        'user/profile/posts',
        query: <String, Object?>{
          'username': username,
          'limit': 50,
          'mature_content': true,
        },
      );
      final rawResults = json['results'];
      if (rawResults is! List) return const <Artwork>[];
      final items = <Artwork>[];
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final url = raw['url'];
        if (url is! String || !url.contains('/journal/')) continue;
        items.add(RfyFeedFetcher.mapDeviation(raw));
      }
      return items;
    });

/// The contents of one gallery folder.
final folderContentsProvider = StateNotifierProvider.autoDispose
    .family<ArtworkFeedController, ArtworkFeedState, FolderRequest>((
      ref,
      request,
    ) {
      final runtime = ref.watch(runtimeProvider);
      final controller = ArtworkFeedController((page) {
        return OfficialFolderRepository(runtime.transport!).galleryContents(
          request.folderId,
          username: request.username,
          request: page,
        );
      });
      return controller;
    });

final class FolderRequest {
  const FolderRequest({required this.username, required this.folderId});

  final String username;
  final String folderId;

  @override
  bool operator ==(Object other) =>
      other is FolderRequest &&
      other.username == username &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(username, folderId);
}
