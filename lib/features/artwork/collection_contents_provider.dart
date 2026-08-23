import 'package:dakit_core/dakit_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/data/web_collection_contents.dart';
import '../../core/runtime/runtime_provider.dart';

/// Identifies a DeviantArt favourites collection by its numeric web folder id
/// and the owner's username.
final class CollectionContentsKey {
  const CollectionContentsKey({required this.folderId, required this.username});

  final int folderId;
  final String username;

  @override
  bool operator ==(Object other) =>
      other is CollectionContentsKey &&
      other.folderId == folderId &&
      other.username == username;

  @override
  int get hashCode => Object.hash(folderId, username);
}

/// The full contents of a favourites collection. Uses the lightweight
/// `gallection/contents` JSON endpoint when a web session (Cookie + CSRF) is
/// available, and falls back to the server-rendered folder page otherwise.
final collectionContentsProvider = FutureProvider.autoDispose
    .family<List<Artwork>, CollectionContentsKey>((ref, key) async {
      final runtime = ref.watch(runtimeProvider);
      final webSession = ref.watch(webSessionProvider);
      final csrf = ref.watch(
        webSessionControllerProvider.select((web) => web.csrf),
      );
      final cookieHeader = await webSession.cookieHeader();
      return WebCollectionContentsSource(
        runtime.dio!,
        cookieHeader: cookieHeader,
        csrfToken: csrf,
      ).contents(key.folderId, key.username);
    });
