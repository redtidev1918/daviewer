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
                    canonical artworkById
                            ↓
                    ArtworkStore.setTags
```

List endpoints may legally omit fields such as tags. An empty list therefore
does not prove that a work is tagless until the canonical detail endpoint has
been queried. `ArtworkStore` records that resolution separately, including a
confirmed empty result, and preserves hydrated tags when a later feed refresh
contains a sparse object.

Rules:

1. Do not make every feed eagerly fetch every detail; hydrate only the field the
   visible screen needs.
2. Do not replace a rich cached object with a sparse list object without a merge
   rule.
3. Cache a confirmed empty result so genuinely tagless works do not refetch on
   every visit.
4. A hydration failure may hide that optional section, but must not make the
   artwork detail page unusable.

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
  ad-hoc signed until Developer ID signing and notarization are configured.
- Historical releases and tags are part of the project record and are retained.
