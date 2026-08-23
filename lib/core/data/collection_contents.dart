import 'package:dakit_core/dakit_core.dart';

/// Fetches the full contents of a DeviantArt collection given its numeric web
/// `folderId`.
///
/// The official API only accepts a UUID `folderid`, while the "More Like This"
/// preview only exposes the numeric web id (`CollectionSummary.folderId`), so
/// opening a collection's full contents has no clean official path today. This
/// abstraction keeps the UI independent of that gap: an official implementation
/// can replace the web fallback later without touching a single screen.
///
/// The current UI already opens a collection natively when the preview carries
/// its deviations, and falls back to the web otherwise. To add a
/// reverse-engineered full-contents source later:
///   1. Implement `contents()` here against DeviantArt's `_puppy` JSON surface
///      (same family as `_puppy/dadeviation/init`), using the web session
///      Cookie/CSRF already available via `WebSession`.
///   2. Verify the exact endpoint + response shape against the live site
///      (browser Network tab on a collection page).
///   3. Wire it into `_openCollection` in `collection_sections.dart` as the
///      first attempt, keeping the preview/browser path as the fallback.
abstract interface class CollectionContentsSource {
  Future<List<Artwork>> contents(int folderId, String username);
}
