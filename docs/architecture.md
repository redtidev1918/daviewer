# DAViewer architecture

This document defines the boundaries that are easiest to blur when fixing feed,
detail, authentication, media, and release bugs.

## SDK and app boundary

- **DAKit** owns OAuth, official DeviantArt API transports and DTO mapping,
  domain models, secure token storage, and background transfers.
- **DAViewer** owns web-session endpoints that have no official equivalent,
  source fallback policy, native navigation and gestures, UI state, and
  host-level caching.
- Web responses are mapped into DAKit domain models before entering feature
  code. Features must not maintain a second artwork model.

Before adding an app workaround, verify whether the official response was
mapped incorrectly. Fix mapping and transport contracts in DAKit; fix source
composition, sparse-data hydration, caching, and presentation in DAViewer.

## Artwork data flow

```text
official/web list source
        ↓ (possibly sparse Artwork)
ArtworkStore.putAll
        ↓
feed card → detail route → artworkDetailProvider
                            ↓ missing detail-only field
                  deviation/metadata adapter
                            ↓
                    ArtworkStore.setTags
```

List endpoints may legally omit fields such as tags, and `deviation/{id}` does
not reliably add them back. An empty list therefore does not prove that a work
is tagless until the dedicated `deviation/metadata` endpoint confirms it.
`ArtworkStore` records that resolution separately, including a confirmed empty
result, and preserves hydrated tags when a later feed refresh contains a sparse
object.

Rules:

1. Do not make every feed eagerly fetch every detail; hydrate only the field the
   visible screen needs.
2. Do not replace a rich cached object with a sparse list object without a merge
   rule.
3. Cache a confirmed empty result so genuinely tagless works do not refetch on
   every visit.
4. A hydration failure may hide that optional section, but must not make the
   artwork detail page unusable.

## Related-content state

Website recommendation data has two supported server-rendered shapes: the
current streamed `window.__RCACHE__.relatedContent` payload and the legacy
normalized `window.__INITIAL_STATE__` metadata/entities. The streamed cache is
preferred when complete, then parsing falls back to the legacy state. A missing
`currentBiMetadata` entry or missing normalized entities is inconclusive, not a
confirmed empty recommendation set. An empty success is shown only when the
website parse and official fallback both finish without errors.

Related **artwork** comes from the website source when available (it can diverge
from the legacy preview) and falls back to the official `browse/morelikethis`
preview. Featured/suggested **collections** exist only in the official preview,
so `moreLikeThisProvider` always fetches the official result and merges it with
the website artwork (`mergeMoreLikeThisResult`); the collection rails therefore
show consistently instead of disappearing whenever the website source happens
to return artwork.

Refreshing related content is one awaited operation. Existing cards remain
visible during it, and completion must report one of three outcomes: changed,
unchanged, or still empty. Source failures retain their network, session,
service, or page-format classification instead of being masked by an empty
fallback.

Provider/parser names and raw exception messages are diagnostic data. User copy
describes only the outcome and next action (checking, updated, unchanged, no
result, sign in, check network, or try later).

## Collection contents and artist discovery

**Collection full contents** (`WebCollectionContentsFetcher`): the official API
only accepts a UUID `folderid`, while the preview exposes a numeric id, so there
is no official full-contents path. DAViewer reads the same server-rendered page
the website serves — `deviantart.com/{username}/favourites/{folderId}?page=N` —
whose `window.__INITIAL_STATE__` embeds the folder's deviations with full Wix
media descriptors. These pages are public, so no login is required. The mapping
reuses `RfyFeedFetcher.mapDeviation` (the shared web-deviation shape). The UI
shows the preview deviations instantly and swaps in the full list when ready,
with an "open on the web" fallback.

**More from this artist** (`MoreFromArtistSection`): the author's other recent
works, read from the official `gallery/{username}` first page. This is the
cleanly available "artist discovery" path.

**Similar artists** (`SimilarArtistsSection`): DeviantArt has no public
similar-artists endpoint — the official API only offers `browse/morelikethis`
(deviations + collections), and the website's `biMetadata` `type: "artist"` hint
is BI tracking (the author's account type), not a recommendation payload. The
real "similar deviants" list streams post-hydration from an undocumented
endpoint (absent from `__INITIAL_STATE__`, `__RCACHE__`, and `dadeviation/init`).
DAViewer therefore derives similar artists from the "More Like This" artwork
authors (`similarArtistsFrom`): artists whose work the recommendation engine
surfaced as related are the honest equivalent. A future dedicated source would
be a web-session reverse-engineering effort and must stay out of DAKit.

## Gesture ownership

Artwork browsing and image panning share horizontal movement, so ownership is
state-dependent:

- At 1x zoom, the outer viewer may recognize a horizontal artwork-navigation
  gesture.
- Above 1x zoom, every outer horizontal callback must be `null`; even a lone
  cancel callback registers a competing recognizer and can steal mobile pans.
- Multi-image paging consumes movement first. Artwork navigation begins only
  after a further edge swipe at the first or last internal page.
- Gesture tests must assert both the intended movement and the absence of an
  unintended artwork-navigation callback.

## Authentication boundary

The app has two sessions:

- the web Cookie/CSRF session for personalized website-only feeds;
- OAuth for official API actions such as favourites, watch, and downloads.

Signed-out state is onboarding, not a feed error. First login commits the web
session before OAuth authorization, and a transient post-login 403 is only
recoverable after that commit has been observed.

## Release contract

- `pubspec.yaml` is the only source version edited by the release workflow.
  Flutter exposes it to the app as `FLUTTER_BUILD_NAME`.
- Every tag must have a matching top-level section in `CHANGELOG.md`; CI uses
  that section as the GitHub Release body.
- CI analyzes, checks formatting, tests, and builds Android, macOS, and Windows.
- Android releases require the configured upload keystore. macOS artifacts are
  ad-hoc signed and must use the `macos-unsigned-preview` filename until stable
  Developer ID signing, Hardened Runtime, and notarization are configured.
- Historical releases and tags are part of the project record and are retained.

## App-local state

Some state is deliberately kept client-side and never synced to DeviantArt:

- **Notification read state** (`NotificationReadStore`): DeviantArt exposes no
  public "mark read" endpoint, so the unread dot is a local overlay on top of
  the server's `isNew` flag. It persists locally and does not pretend to sync.
- **User preferences** (`core/settings/AppPreferences`): language and theme
  mode are stored in a small JSON file under the application-support directory.
  They are restored before the first frame so the app never flashes defaults.
- **Theme mode** (`core/theme/ThemeModeController`): system / light / dark, fed
  into the MaterialApp and persisted with the preferences above.

These overlays must stay local: adding a "sync to server" behavior would cross
into the official API boundary and belongs in DAKit, not in the app.
