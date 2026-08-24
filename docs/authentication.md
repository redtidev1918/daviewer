# Authentication and session recovery

DAViewer uses two independent DeviantArt sessions because no single official
API covers all app features:

| Session | Stored data | Used for |
| --- | --- | --- |
| Web | WebView Cookie, CSRF, username snapshot | personalized Home and website-only adapters |
| OAuth | access/refresh tokens in secure storage | favourites, watch, galleries, downloads, and official APIs |

The app never receives or stores the user's DeviantArt, Google, Apple, Facebook,
or Mac password. Login forms belong to DeviantArt and its selected identity
provider; a macOS password dialog belongs to Keychain.

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

## Login routes

The native entry screen presents two routes with genuinely different execution
and proxy boundaries:

- **Social account — system browser.** DAKit creates one PKCE transaction and
  DAViewer arms the OAuth launcher for one external navigation. DeviantArt's
  current page presents Google, Apple, Facebook, or any future provider. Google
  rejects embedded user-agents, so this is the supported Google route rather
  than a WebView with a forged desktop User-Agent. The `dakit://oauth/callback`
  URI resumes the same transaction. Android intent filters and the macOS URL
  type own the scheme; the unpackaged Windows build registers it under the
  current user and forwards activation to the existing process.
- **DeviantArt username/email and password — embedded WebView.** The OAuth
  authorize URL remains inside the app, follows the app WebView proxy where the
  platform permits it, and establishes both OAuth and the Cookie/CSRF web
  session. The app may activate the official DeviantArt account form from the
  join page, but it never simulates a click on a social-provider control.

The login page is fetched read-only through the app network route to discover
provider labels for display. Discovery is never used to build authorization
URLs or receive credentials; failure falls back to a generic social-account
label while the official browser page remains authoritative.

- A system-browser transaction has an explicit waiting screen, a control to
  reopen the exact same authorize URI, and a cancel action. Reopening does not
  create another PKCE state; cancellation clears the pending transaction before
  another attempt can start.
- An OAuth transaction belongs to one visible login attempt. Leaving, retrying,
  disposing the route, or failing to start WebView navigation within 20 seconds
  cancels and awaits that transaction, clears its queued authorize URL, and
  lets the next attempt create a fresh PKCE state. A cancelled transaction must
  never keep `isLoggingIn` true or absorb the next login request.
- Do not add a separate client-id preflight ahead of authorization: a request
  without the generated PKCE challenge is not equivalent to the real flow and
  only delays proxy users on a blank WebView.
- A successful system-browser social login establishes App OAuth but cannot
  export protected browser cookies into the embedded WebView. This is not a
  failed login: favourites, watching, downloads, galleries, and official feeds
  work immediately. Home initially selects the OAuth-backed Daily tab and
  offers embedded web-session synchronization only as an optional step for the
  website-only personalized feed.
- `window.open()` remains attached to a second WebView for official embedded
  navigation, with third-party cookies enabled. It is a compatibility fallback,
  not the supported Google entry path.
- After a password submission, a transient main-frame 403 waits for the
  persistent `userinfo` cookie. If committed, the WebView resumes the same
  authorize URI; otherwise the app shows a recoverable connection state.
- The login screen always exposes Settings. Proxy, diagnostics, update checking,
  About, language, and appearance do not require authentication.
- An interactive human-verification response is part of the official sign-in
  page even when its HTTP status is 403, 429, or 503. The app keeps that page
  visible and resumes the same OAuth transaction after verification; only a
  response without challenge UI is classified as a connection failure.
- Verification is a first-class login state, not a one-shot `loadStop` check.
  A 403/429/503 response enters a visible pending-verification state immediately;
  the main WebView and social popup are then polled for dynamically inserted
  Cloudflare, PerimeterX, reCAPTCHA, hCaptcha, and Arkose controls. Two clean
  observations after a confirmed challenge clear the notice. A response is
  labelled as a network failure only after the interactive document inspection
  completes without a challenge.
- The verification notice is persistent and accessible: it also emits a timed
  snackbar, uses a live region for screen readers, and exposes a reload action.
  Closing a provider popup hands monitoring back to the parent WebView rather
  than polling a disposed page.
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

## Cold-start session evidence

Cold-start recovery must distinguish an existing account from first run. The
secure token store records a separate non-sensitive boolean only after it has
successfully read or written OAuth tokens. A transient network, rate-limit,
upstream, or Keychain failure preserves `signedIn` only when this evidence
exists. Without it, the app stays signed out and keeps Login, Proxy, Settings,
Updates, and Diagnostics available; it must never route a first-run user into a
personalized endpoint that cannot authorize.

The flag contains no token or account identity. A successful empty token-store
read and explicit logout clear it. Reading an expired token sets it before the
refresh request, so an offline refresh still preserves an established user.
