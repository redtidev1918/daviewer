# Authentication and session recovery

DAViewer has one user identity: the official DeviantArt OAuth session. The app
never receives or stores a DeviantArt, Google, Apple, Facebook, or Mac password.
Credentials and provider security checks stay on DeviantArt's official page,
which the app shows inside its own embedded WebView.

## One-entry sign-in contract

The app exposes one **Sign in or create an account** action, which opens the
embedded login screen:

1. DAKit creates one OAuth/PKCE transaction.
2. DAViewer loads the official login page in its embedded WebView with a desktop
   User-Agent, because DeviantArt's mobile login page omits the Google and Apple
   one-click buttons the desktop page offers.
3. DeviantArt's page owns account sign-in, registration, password recovery, and
   every provider it currently offers (DeviantArt, Google, Apple, Facebook).
   There is no separate "social login" route in the app.
4. `dakit://oauth/callback` is intercepted inside the WebView and completes the
   same transaction. The WebView keeps its cookies and CSRF token, so this one
   login also establishes the web session used by the personalized `rfy` feed
   and the collection adapters. No second sign-in is requested.

The app does not simulate a provider-button click, embed a password form, copy
cookies out of a system browser, or inspect human-verification DOM. It does set
a desktop User-Agent so the full desktop login page is served. Google, Apple, or
Facebook may still show their own account or CAPTCHA checks inside the WebView;
those are the providers' pages and are not bypassed by the app.

## Session roles

- **OAuth session** (secure storage) powers the official API: daily
  deviations, search, artwork lookup, favourites, watch, and downloads.
- **Web session** (the WebView's cookies plus the CSRF token and login state,
  persisted locally and restored at startup) powers the website-only adapters:
  the personalized `rfy/deviations` feed and collection contents.

One embedded login establishes both sessions. The WebView reports the web
session (CSRF token and the `userinfo` cookie) only after the OAuth callback has
navigated back to the DeviantArt home page, so the app never records a
signed-out web session from the anonymous login page.

While waiting, the user can cancel and reopen. Cancelling or starting a new
attempt clears the pending transaction so a stale callback cannot absorb a later
login. Settings, proxy, diagnostics, updates, About, language, and appearance
remain reachable before sign-in.

The in-memory PKCE transaction is authoritative while the app process remains
alive. Its secure-storage copy exists only to recover a callback after a process
restart: failure to write, read, or clear that recovery copy must never overturn
the live authorization result. Token storage is different and remains the hard
commit point—sign-in is reported as successful only after the new token is
stored securely.

The `dakit` scheme is owned by the embedded WebView, which intercepts the OAuth
callback and never leaves the app. A system browser is used only as a fallback
when no WebView listener is registered, and for the "content settings" link to
DeviantArt's browsing preferences.

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
4. Explicit logout clears the current OAuth store, session evidence, and the
   WebView cookies.

macOS previews use one private, stable CI signing identity. The identity is
self-signed, not Apple trusted or notarized, but it prevents a changing ad-hoc
cdhash from requesting the Mac password after each update. Version 0.2.139 moves
token and recovery storage to the fresh `DAViewer Account` Keychain service and
does not query `DAViewer OAuth` or older ad-hoc items. This avoids an inaccessible
legacy record blocking authorization. The upgrade requires one new sign-in while
keeping downloads, settings, and other local data; later previews keep the same
service and signing identity.

The Home **推荐 / For you** tab is the website's personalized `rfy/deviations`
feed, fetched with the WebView's Cookie and CSRF token. It requires a signed-in
web session; when the web session is absent the tab shows the sign-in prompt.
The **每日精选 / Daily** tab uses the official OAuth API and does not depend on
the web session. The product must not label these two sources as equivalent.

## Public website adapters

A few detail-page features require undocumented public website data, such as
numeric-id resolution and collection contents. The embedded WebView's web
session (cookies and CSRF token) provides this on demand. This is infrastructure
state, not a second user identity: it never blocks Home, never asks the user to
log in again, and must degrade to a retry or official-API fallback when
unavailable.

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
failure. Secure-storage errors are never displayed as the raw phrase “Unable to
access”; token-storage failures are distinguished from recovery-record cleanup
warnings so the user is not told that a completed authorization was a network or
account failure.
