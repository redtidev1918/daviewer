import 'package:dakit_core/dakit_core.dart';

/// Fetches the full contents of a DeviantArt collection given its numeric web
/// `folderId`.
///
/// The official OAuth API only accepts a UUID `folderid`, while the "More Like
/// This" preview only exposes the numeric web id (`CollectionSummary.folderId`),
/// so opening a collection's full contents has no clean official path today.
/// This abstraction keeps the UI independent of that gap.
///
/// The current implementation is [WebCollectionContentsSource] (see
/// `web_collection_contents.dart`), which reads the server-rendered favourites
/// folder page the website itself serves. A future official (UUID-based)
/// implementation can replace it without touching a single screen.
abstract interface class CollectionContentsSource {
  Future<List<Artwork>> contents(int folderId, String username);
}
