# Web adapter — compatibility contract

DAViewer talks to two DeviantArt surfaces:

- **Official OAuth API** (stable, versioned, owned by DAKit).
- **Website-private JSON/HTML endpoints** (unstable, undocumented) for the few
  detail features the official API does not expose: numeric-id resolution,
  related-artwork blocks, collection full contents, real deviation search,
  gallery keyword search, and profile facts (watchers/join date).

This document is the compatibility contract for that second, private surface.
Its job is not to prevent DeviantArt from changing — that is out of our
control — but to make any change **cheap to detect and cheap to fix**.

## Where the code lives

These modules are intentionally kept in DAViewer (not in DAKit, not in a
separate published package). They depend on undocumented, volatile endpoints,
so publishing them would promise a stability that does not exist. They are
grouped under `lib/core/data/` and must never leak HTML/JSON parsing into
feature code.

## The three-layer defense

1. **Stable interface isolation.** Feature code depends on a small interface or
   a DAKit domain model (`CollectionContentsSource.contents`, `Artwork`,
   `DeviationInit`), never on raw HTML/JSON. A site change is fixed inside one
   adapter without touching a screen.

2. **Tolerant parsing + graceful degradation.** Every adapter parses
   defensively (a malformed entry is skipped, not fatal) and has a fallback:
   the official API, the preview data, or simply hiding the optional section.
   A web failure must never take down the artwork detail page.

3. **Contract tests against captured snapshots.** Each parser has a committed
   unit test with a synthetic fixture, plus a gated live-snapshot test that
   reads a real captured page when the corresponding `DA_*` dart-define points
   at it. When DeviantArt changes shape, the snapshot test turns red and names
   the exact parser.

## Endpoint registry

| Feature | Module | Endpoint / source | Session | Fallback | Contract test (snapshot define) |
| --- | --- | --- | --- | --- | --- |
| Personalized home feed | `rfy_feed.dart` | `_puppy/dabrowse/networkbar/rfy/deviations` | web Cookie + CSRF (signed-in) | none (needs the web session; shows sign-in prompt) | `rfy_feed_test.dart` — `updatedTime ?? publishedTime` feeds the artwork timestamp so ordering reflects edits |
| Numeric→UUID + description + dates | `deviation_init.dart` | `_puppy/dadeviation/init` | anonymous browser CSRF | description falls back to the short excerpt; tags empty (official `deviation/metadata` serves only OAuth items); dates fall back to the feed item's publish time | `deviation_init_test.dart` (`DA_DEVIATION_INIT_JSON`) — also parses `publishedTime` / `updatedTime` for the detail date rows |
| Related artwork | `web_more_like_this.dart` | artwork page `__INITIAL_STATE__` / `__RCACHE__` | none (public) | official `browse/morelikethis` | `web_more_like_this_test.dart` (`DA_MORE_LIKE_THIS_HTML`) |
| Collection full contents | `web_collection_contents.dart` | `_puppy/dashared/gallection/contents` (JSON), fallback `deviantart.com/{user}/favourites/{id}?page=N` | anonymous browser CSRF (JSON) / none (SSR) | preview deviations + open-on-web | `web_collection_contents_test.dart` (`DA_COLLECTION_JSON`, `DA_COLLECTION_HTML`) |
| Deviation search | `web_search.dart` | `_puppy/dabrowse/search/deviations` | web Cookie + CSRF (signed-in) | official `browse/home?q=` (coarse, no web session) | `web_search_test.dart` |
| Gallery keyword search | `web_gallery_search.dart` | `_puppy/dashared/gallection/search` | anonymous browser CSRF | none (search needs the web session) | `web_gallery_search_test.dart` |
| Profile facts (watchers/join date) | `web_user_profile.dart` | `_puppy/dauserprofile/init/about` | anonymous browser CSRF | none (header omits the enrichment) | `web_user_profile_test.dart` |

Shared, non-endpoint helpers (no separate fallback, tested directly):

| Helper | Module | Purpose | Test |
| --- | --- | --- | --- |
| Wix media descriptor → URL | `wix_media.dart` | `baseUri` + `prettyName` + `types` resolution | `wix_media_test.dart` |
| JS literal JSON decoder | `html_state.dart` | `window.__X = JSON.parse("…")` decoding | via the snapshot tests above |
| HTML / tiptap → text/html | `html_text.dart` | description rendering | `html_text_test.dart` |
| Public browser state | `web_session.dart` | read anonymous browser cookies | `web_session_refresh_policy_test.dart` |
| Link → route | `da_uri.dart` | paste-link parsing (no network) | `da_uri_test.dart` |

Sections that are derived or use the official API (`more_from_artist`,
`similar_artists`) are **not** web adapters and are excluded here.

## When DeviantArt changes: runbook

1. **Run the snapshot tests** with the latest capture to see which parser broke:

   ```bash
   flutter test --dart-define=DA_MORE_LIKE_THIS_HTML=/path/to/artwork.html \
                --dart-define=DA_COLLECTION_HTML=/path/to/folder.html \
                --dart-define=DA_DEVIATION_INIT_JSON=/path/to/init.json
   ```

2. **Isolate the failure** to one adapter. A red snapshot means "the shape of
   that one endpoint changed", not "the app is broken".

3. **Fix the parser** in that one file, keeping the mapped DAKit model
   unchanged. Prefer tolerant reads (skip the bad entry) over strict parsing
   unless the endpoint is wholly gone.

4. **Refresh the snapshot** and re-run; then update the endpoint registry above
   if the URL or fallback changed.

5. **If the endpoint is removed**, do not invent a replacement. Swap in the
   official API path or hide the section, and update the fallback column here.

## Capturing snapshots

Snapshots are real responses saved locally (they are **not** committed — they
are large and change every time the site does). To capture one:

- **Public pages** (artwork, collection): save the page HTML with a browser
  User-Agent (login not required).
- **Browser-shaped endpoints** (`dadeviation/init`): capture the JSON response
  from a public browser session. Do not include account cookies in fixtures.

The `DA_*` dart-defines point at those files; when unset, the gated tests skip,
so CI never depends on a captured page.
