# Authentication and session recovery

DAViewer has one user identity: the official DeviantArt OAuth session. The app
never receives or stores a DeviantArt, Google, Apple, Facebook, or Mac password.
Credentials and provider security checks stay in the user's system browser.
DAViewer never asks for the Mac login password; a package that does so must be
denied and reported.

## One-entry sign-in contract

The native screen exposes one **Sign in or create an account** action:

1. DAKit creates one OAuth/PKCE transaction.
2. DAViewer opens its exact authorize URI in the system browser.
3. DeviantArt's current page owns account sign-in, registration, password
   recovery, and any providers it offers, such as Google, Apple, or Facebook.
4. `dakit://oauth/callback` completes the same transaction and returns to the
   app. No second web-session sign-in is requested.

The app does not forge a desktop User-Agent, simulate a provider-button click,
embed a password form, copy browser cookies, or inspect human-verification DOM.
HTTP 403, 429, and 503 can be valid interactive security pages in the browser;
the in-app connectivity test therefore reports only whether the App network
route is reachable and never diagnoses the browser's provider flow.

While waiting, the user can reopen the same authorize URI or cancel. Reopening
does not create another PKCE state. Cancelling, leaving the route, or starting a
new attempt clears the pending transaction so a stale callback cannot absorb a
later login. Settings, proxy, diagnostics, updates, About, language, and
appearance remain reachable before sign-in.

Android intent filters and the macOS URL type own the callback scheme. The
unpackaged Windows build registers it under the current user and forwards a
callback activation to the existing process.

## Cold-start contract

1. With no cold-start OAuth callback, skip pending-transaction storage and read
   only the current OAuth token.
2. Treat only missing or revoked credentials as signed out. Temporary network,
   upstream, timeout, parsing, and Keychain-availability failures preserve an
   established session.
3. Record non-sensitive session evidence only after secure storage has
   successfully read or written tokens. This prevents a first-run network error
   from routing an anonymous user into Home while preserving offline recovery
   for existing users.
4. Explicit logout clears the current OAuth store, session evidence, and legacy
   browser cookies.

macOS previews from 0.2.138 use one private, stable CI signing identity and a
new Keychain service. The identity is self-signed, not Apple trusted or
notarized, but it prevents a changing ad-hoc cdhash from requesting the Mac
password after each update. The app intentionally does not query older items;
an upgrade from an older preview requires one new browser sign-in while keeping
downloads, settings, and other local data.

The Home recommendation tab uses the official OAuth `browse/home` endpoint, so
successful browser authorization immediately enables recommendations,
favourites, watch, galleries, downloads, and other official APIs.

## Public website adapters

A few detail-page features require undocumented public website data, such as
numeric-id resolution and collection contents. A hidden browser may obtain an
anonymous CSRF/cookie snapshot on demand. This is infrastructure state, not a
second user identity: it never blocks Home, never asks the user to log in, and
must degrade to a retry or official-API fallback when unavailable.

Legacy browser cookies are accepted only for public adapter compatibility. If
they expose a username different from the OAuth account, they are cleared to
prevent mixed-account data.

## Mature content

`mature_content: true` is only a request flag. DeviantArt account browsing
preferences remain authoritative and may hide or blur adult content. Settings
links directly to DeviantArt's browsing preferences; the app does not bypass
account restrictions.

## User-facing error policy

Raw endpoint names, parser errors, HTTP payloads, package identifiers, and
provider internals belong in Diagnostics. User UI states what failed and the
next useful action. Authentication errors offer retry, reopen, cancel, proxy,
and settings paths without claiming that a provider challenge is an App network
failure.
