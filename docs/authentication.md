# Authentication and session recovery

DAViewer uses two independent DeviantArt sessions because no single official
API covers all app features:

| Session | Stored data | Used for |
| --- | --- | --- |
| Web | WebView Cookie, CSRF, username snapshot | personalized Home and website-only adapters |
| OAuth | access/refresh tokens in secure storage | favourites, watch, galleries, downloads, and official APIs |

The app never receives or stores the user's DeviantArt, Google, Apple, or Mac
password. The login form belongs to DeviantArt in an embedded browser; a macOS
password dialog belongs to Keychain.

## Cold-start contract

1. Restore the persisted web-session snapshot before routing away from Splash.
2. Read the current OAuth Keychain item. If it is absent, read the pre-migration
   item and copy the tokens forward without deleting the rollback copy.
3. Treat only missing/revoked credentials as signed out. Network, upstream,
   timeout, parsing, and Keychain availability failures preserve the session.
4. Refresh the web page headlessly only when a prior web identity exists. A new
   CSRF is committed only when the same page also exposes a username; bot-check
   and partial pages cannot erase the session.
5. Coalesce overlapping first-page feed refreshes so lifecycle, CSRF, and user
   refresh events cannot race or create retry loops.

Explicit logout clears both current and legacy OAuth stores, WebView cookies,
and the web-session snapshot.

## Login WebView

- A native entry screen presents DeviantArt, Google / Apple, registration,
  password recovery, and network checks before opening any website.
- Mobile presents DeviantArt's desktop login layout so Google and Apple buttons
  remain visible.
- `window.open()` navigation is kept in the same WebView and third-party cookies
  are enabled for the social-login handshake.
- After a password submission, a transient main-frame 403 waits for the
  persistent `userinfo` cookie. If committed, the WebView moves to Home and
  records a fresh CSRF; otherwise the app shows a recoverable connection state.
- The login screen always exposes Settings. Proxy, diagnostics, update checking,
  About, language, and appearance do not require authentication.
- Interactive and headless WebViews use the effective app proxy where the OS
  allows it, and Windows cookie reads share the same WebView2 environment. See
  [Networking and proxy](networking.md) for platform limits.

## Mature content

`mature_content: true` is only a request flag. DeviantArt account browsing
preferences remain authoritative and may hide or blur adult content. The app
provides a direct Settings entry to DeviantArt's browsing preferences; the app
does not bypass account restrictions.

## User-facing error policy

Raw endpoint names, parser errors, HTTP payloads, and provider details belong in
Diagnostics. UI copy states the outcome and next action. A personalized-feed
failure stops automatic retries, keeps session data intact, and offers pull to
refresh plus the proxy/settings path.
