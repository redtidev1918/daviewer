# DAViewer

<p align="center">
  <img src="assets/icon/icon.png" alt="DAViewer" width="160" />
</p>

**Language:** English · [中文](README.md)

> DeviantArt has discontinued its official client app. DAViewer is an
> open-source DeviantArt client built on
> [DAKit](https://github.com/redtidev1918/dakit), providing the website's core
> features as a native app for Android, macOS, and Windows.

[![GitHub stars](https://img.shields.io/github/stars/redtidev1918/daviewer?style=flat&color=yellow)](https://github.com/redtidev1918/daviewer/stargazers)
[![GitHub license](https://img.shields.io/github/license/redtidev1918/daviewer?style=flat)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/redtidev1918/daviewer?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20macOS%20%7C%20Windows-blue?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-blue?style=flat&logo=flutter)](https://flutter.dev)

## Install

Download the package for your platform from
[Releases](https://github.com/redtidev1918/daviewer/releases):

- **Android**: `DAViewer-<version>.apk`
- **macOS 12+ unsigned test preview**:
  `DAViewer-<version>-macos-unsigned-preview.zip` (universal Intel and Apple
  Silicon build; unzip and drag to Applications)
- **Windows**: `DAViewer-<version>-windows.zip` (unzip and run `DAViewer.exe`)

On a normal first launch, the Windows ZIP build registers only the current-user
`HKCU\\Software\\Classes\\dakit` OAuth callback scheme (used for external-browser
fallback sign-in). It needs no administrator rights, installs no service, and
reads no system password. Launching again after moving the folder refreshes the
path.

> **A note on the macOS build:** this is explicitly a **non-Apple-signed,
> unnotarized test preview**. CI uses a stable project-owned preview identity
> only to keep Keychain continuity; it is not trusted by Apple and does not
> bypass Gatekeeper. Right-click the app and choose Open on first launch.
> DAViewer does not request or read your Mac login password. Deny and report
> any package that displays such a request.

## Screenshots

<table align="center">
  <tr>
    <td align="center"><img src="docs/screenshots/home_feed.jpg" width="200" /><br /><sub>Home feed</sub></td>
    <td align="center"><img src="docs/screenshots/artwork_detail.jpg" width="200" /><br /><sub>Artwork detail</sub></td>
    <td align="center"><img src="docs/screenshots/related_works.jpg" width="200" /><br /><sub>Related works</sub></td>
  </tr>
</table>

## Contents

- [Why](#why)
- [Features](#features)
- [Relationship with DAKit](#relationship-with-dakit)
- [Before you start](#before-you-start)
- [Run](#run)
- [Proxy](#proxy)
- [Build & release](#build--release)
- [Home & sign-in state](#home--sign-in-state)
- [Login FAQ](#login-faq)
- [Contributing](#contributing)
- [Notes](#notes)

## Why

- DeviantArt has discontinued its official client app;
- The website has rich functionality (recommendations, galleries,
  tags, favourites, watch, download) but no native desktop/mobile experience;
- This project combines the website's core features with native interaction,
  out of the box — no need to register your own OAuth app.

## Features

- **Sign in**: one "Sign in or create an account" action opens DeviantArt's
  official login page in the app's embedded WebView; choose DeviantArt, Google,
  Apple, or Facebook right on that page. One login establishes both the OAuth
  session and the web session (personalized feed, collections)
- **Discovery**: Home “Discover” uses the official generic OAuth `browse/home`
  stream and is not presented as the website's personalized feed
- **Search**: live search (results as you type) + history + paste a DeviantArt
  link to jump straight to an artwork or artist
- **Artwork detail**: swipe or top-bar buttons to browse previous/next works
  (adjacent images prefetched); pinch zoom; paged multi-image works
- **Media**: shared image zoom; highest-quality video with seeking and retry;
  GIF badge + cached rich-text images with loading progress
- **Related content**: native "More like this", similar artists,
  featured/suggested collections (openable in full), and "More from this
  artist" on the detail page, with clear empty and failure states
- **Tags**: one compact tag row across detail, search, and tag screens, with
  automatic tag hydration from official metadata
- **Artist**: profile (including bio), gallery, **custom sub-galleries
  (folders)**, favourites, watch
- **Sharing**: native system sharing for artwork, artists, gallery folders,
  favourite collections, and tags; artwork links can still be copied separately
- **Social**: favourite (with state), watch/unwatch, watched-user list,
  notifications (unread dot + local mark-as-read)
- **Download**: real-time original-file permission check; thumbnail previews;
  explains login, purchase, quota, or creator restrictions and falls back to the
  highest-quality preview; open file/folder and delete confirmation
- **Appearance & settings**: light / dark / system theme; persisted language and
  theme; clear cache; check for updates
- **Bilingual**: Chinese / English toggle
- **Proxy**: auto-detect the system proxy + manual configuration (required in
  mainland China)

## Relationship with DAKit

`DAViewer` is the app; DAKit is the SDK. The client only depends on DAKit and
does not copy SDK code: OAuth, official API mapping, domain models, and
background transfers live in DAKit, while website sparse-data hydration and
native interaction live in DAViewer. Dependencies:

```yaml
dependencies:
  dakit_core: ^0.1.12
  dakit_api: ^0.1.25
  dakit_flutter: ^0.1.9
```

Each attempt creates one official OAuth/PKCE transaction. Account selection,
passwords, and provider security checks stay on DeviantArt's official page inside
the app's embedded WebView. After the callback, every feature uses that one
OAuth identity plus the WebView's web session; there is no second web sign-in to
synchronize. Signed-out state is onboarding, not a feed error. See
[Architecture](docs/architecture.md) for the full boundaries.

## Before you start

Ordinary users only need a DeviantArt account — no OAuth app registration is
required. The client bundles a public client id (a Public OAuth client has no
secret, so the client id can be distributed with the app).

> Sign-in requests these OAuth scopes (requested automatically at launch):
> `basic`, `browse`, `collection` (favourites), `user` (watch list),
> `user.manage` (watch/unwatch), `gallery`, `feed`.

### Developers: override the bundled client id

To use your own OAuth app (e.g. for development), override it via
`--dart-define`:

```shell
flutter run -d macos --dart-define=DAKIT_CLIENT_ID=YOUR_PUBLIC_CLIENT_ID
```

> When using your own app, add `dakit://oauth/callback` verbatim to its
> whitelist.

## Run

```shell
flutter pub get
flutter run -d macos     # macOS
flutter run -d android   # Android
flutter run -d windows   # Windows
```

## Proxy

The runtime network path is selected in this order: in-app manual setting,
system proxy, `https_proxy` / `http_proxy` / `all_proxy`, then build setting.
Settings → Proxy accepts `127.0.0.1:<YOUR_PORT>` or
`http://127.0.0.1:<YOUR_PORT>`, persists
the choice, and applies it to API, media, downloads, and hidden public website
adapters. The page tests the App route to DeviantArt. Sign-in happens in the
app's embedded WebView and therefore follows the app network path (a manual
proxy applies to the login page too).

The port is never fixed: use the HTTP/Mixed port shown by your proxy app. On a
phone, `127.0.0.1` is correct only when the proxy runs on that same phone. If it
runs on a computer or router, enter its LAN IP and enable LAN access. The app
tests reachability first, so directly connected users are not pushed toward a
proxy while restricted networks receive the relevant recovery steps.

Apps launched from Finder usually do not inherit terminal variables. On macOS
12/13 an app-only proxy cannot be injected into the hidden browser adapter, so
use the macOS system proxy. See [Networking and proxy](docs/networking.md) for
the full priority, platform matrix, and troubleshooting flow.

Environment variables for proxying `flutter pub get` and Gradle builds are in
[Build notes](docs/build.md#proxying-builds).

## Build & release

Pushes to `main` trigger CI quality checks and Android/macOS/Windows builds;
pushing a `v*` tag creates a GitHub Release whose notes come from the matching
user-facing `RELEASE_NOTES.md` section.

**One-click release (recommended)**: Actions → **Release** → Run workflow → pick
`patch` / `minor` / `major` (or an exact version) → run. It bumps the version,
commits, pushes the tag, and CI builds and publishes.

Local verification builds:

```shell
flutter build apk --release          # Android APK (requires android/key.properties)
flutter build macos --release        # macOS app
flutter build windows --release      # Windows app
```

Signing, the pinned toolchain (AGP / Gradle / Kotlin / flutter_inappwebview), and
the macOS unsigned-preview contract are detailed in
[Build notes](docs/build.md).

## Home & sign-in state

Home is a **native UI** (Discover / Daily tabs), plus a first-class **Watched**
bottom tab (DeviantArt's `/watch/deviations` — new artwork from watched artists,
with a recency-sorted avatar strip). Discover is the official generic
`browse/home` stream; it is not equivalent to the cookie-backed website
`rfy/deviations` personalized feed. Discover and Daily use official OAuth APIs
and share the same identity as favourites, watch, and downloads. DeviantArt's
official page inside the app's embedded WebView owns account sign-in,
registration, social providers, and security checks. `dakit://oauth/callback` is
intercepted in the WebView to complete sign-in; there is no second browser
identity to synchronize.

macOS previews use a stable project identity. Version 0.2.139 moves sign-in data
to a fresh `DAViewer Account` Keychain item and no longer queries the 0.2.138
`DAViewer OAuth` item or older ad-hoc items. This prevents an inaccessible legacy
record from turning a completed authorization into “Unable to access”. The
upgrade needs one fresh official sign-in, while downloads, settings, and other
local data remain. Pending PKCE data is now recovery-only and cannot block a
live sign-in when it cannot be stored or cleared.

## Login FAQ

- **DAViewer has no account of its own**: you sign in with your DeviantArt account — the app never registers an account or stores a password.
- **Password reset / registration**: tap "Sign in or create an account" and use the actions offered by DeviantArt's official page.
- **Google / Apple / Facebook sign-in**: open DeviantArt's official login page in the app's embedded WebView, then choose a provider right on the page (Google, Apple, and other options are on the page itself). The callback returns to DAViewer after one login.
- **Sign-in and proxies**: sign-in happens in the app's embedded WebView and follows the app network path; a manually entered proxy covers the login page too. If the page cannot open, run the connectivity test before signing in.
- **Check proxy before sign-in**: the native screen shows the effective route and provides both proxy settings and a connectivity test before any web page is opened.
- **Human verification**: this belongs to the official page or identity provider and is completed inside the embedded WebView. DAViewer does not guess that 403/429/503 means an outage or interfere with it.
- **The page did not open or is stuck**: tap the top-right "Done" to close and reopen the login screen. Cancel before starting a completely new transaction.
- **First run and offline recovery**: the app preserves sign-in through a temporary network or provider failure only after this installation has successfully stored an OAuth session. A never-signed-in user is not routed into a failing Home, while an established user's token is not erased by an outage.
- **Mature content**: DeviantArt account browsing preferences override the app request. Open Settings → DeviantArt account settings → Mature content settings.
- **Settings while sign-in is broken**: the gear on the login screen keeps language, proxy, diagnostics, updates, and About reachable without authentication.
- **macOS asks for your Mac password**: deny the request, do not enter the password, and report the version and a screenshot. Version 0.2.139 uses a fresh Keychain item, so the upgrade needs one new sign-in without deleting downloads or settings.

See [Authentication and session recovery](docs/authentication.md) for the full
state contract.

## Contributing

All contributions are welcome — issues, bug fixes, features, and docs. See
[CONTRIBUTING.md](CONTRIBUTING.md). Report security issues via
[SECURITY.md](SECURITY.md), and see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for
community guidelines.

1. Fork the repository and branch from `main`;
2. Run `dart format lib test`, `flutter analyze`, and `flutter test`;
3. Open a PR describing what changed and why.

The SDK the client depends on is [DAKit](https://github.com/redtidev1918/dakit)
(published to pub.dev); SDK changes belong there, and the two are released
together.

If this project is useful to you, **star it** so more people can find it.

## Notes

- `DAViewer` is a third-party client and is not affiliated with DeviantArt;
- The client does not store a `client_secret`;
- All account authorization uses DeviantArt's official page in the system
  browser. DAViewer never embeds or reads an account/password form of its own.
