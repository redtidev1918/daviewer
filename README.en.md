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

> **A note on the macOS build:** this is explicitly an **unsigned, unnotarized
> test preview** and isn't part of the Apple Developer
> Program yet, so macOS may ask you to confirm on first launch — right-click the
> app and choose Open to proceed. Keychain may ask for your Mac password once;
> that prompt is handled by macOS and DAViewer never reads or stores it.
> Everything else works like a normal app.

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
- The website has rich functionality (personalized recommendations, galleries,
  tags, favourites, watch, download) but no native desktop/mobile experience;
- This project combines the website's core features with native interaction,
  out of the box — no need to register your own OAuth app.

## Features

- **Sign in**: one login establishes both the web session and OAuth (bundled
  public client id, no OAuth app registration needed)
- **Recommendations**: the home "For you" tab is the website's personalized feed
  (`rfy/deviations`), matching the website
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
background transfers live in DAKit, while website-personalized feeds,
sparse-data hydration, and native interaction live in DAViewer. Dependencies:

```yaml
dependencies:
  dakit_core: ^0.1.12
  dakit_api: ^0.1.19
  dakit_flutter: ^0.1.9
```

First sign-in uses one official OAuth/PKCE navigation to establish both the web
Cookie/CSRF session and app OAuth, instead of starting a second authorization
after social sign-in. Signed-out state is normal onboarding, not a feed error. See
[Architecture](docs/architecture.md) for the full data flow and boundaries.

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
the choice, and applies it to API, media, downloads, background web sessions,
and sign-in. The page includes a direct DeviantArt connectivity check.

The port is never fixed: use the HTTP/Mixed port shown by your proxy app. On a
phone, `127.0.0.1` is correct only when the proxy runs on that same phone. If it
runs on a computer or router, enter its LAN IP and enable LAN access. The app
tests reachability first, so directly connected users are not pushed toward a
proxy while restricted networks receive the relevant recovery steps.

Apps launched from Finder usually do not inherit terminal variables. On macOS
12/13 an app-only proxy cannot be injected into the system WebView, so use the
macOS system proxy; macOS 14+, Android, and Windows can route the sign-in WebView
through the in-app setting. See [Networking and proxy](docs/networking.md) for
the full priority, platform matrix, and troubleshooting flow.

Environment variables for proxying `flutter pub get` and Gradle builds are in
[Build notes](docs/build.md#proxying-builds).

## Build & release

Pushes to `main` trigger CI quality checks and Android/macOS/Windows builds;
pushing a `v*` tag creates a GitHub Release whose notes come from the matching
`CHANGELOG.md` section.

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

Home is a **native UI** (For you / Daily tabs), plus a first-class **Watched**
bottom tab (DeviantArt's `/watch/deviations` — new artwork from watched artists,
with a recency-sorted avatar strip). The "For you" feed is powered by
DeviantArt's website personalized endpoint (`rfy/deviations`); the official
OAuth API has no equivalent, so it needs the **web session (Cookie + CSRF)**.

The app has two independent sign-in states:

- **Web session**: established by the built-in WebView (Cookie + CSRF); decides
  whether "For you" is personalized. It is silently refreshed on cold start, so
  no manual login is needed each time.
- **App OAuth session**: decides whether favourites / watch / download work.

Sign-in starts with a native choice screen for DeviantArt, Google, Apple,
registration, password recovery, or proxy setup, and opens DeviantArt's page
only after an explicit action. First sign-in begins at the OAuth authorize URL;
the password page and social popup return to that same PKCE transaction, so one
navigation establishes both sessions. If they later drift out of sync, Home
offers a one-tap fix. The system browser remains the fallback when the embedded
WebView is unavailable.

Upgrades do not proactively delete sessions. If the macOS Keychain item name
changes, the app reads the new location first and then non-destructively copies
tokens from the legacy location. Temporary network, upstream, or Keychain
failures are not treated as sign-out; only missing/revoked credentials or an
explicit logout require authorization again.

## Login FAQ

- **DAViewer has no account of its own**: you sign in with your DeviantArt account — the app never registers an account or stores a password.
- **Password reset / registration**: the native sign-in screen exposes both actions; the system browser opens only after you tap one.
- **Google / Apple sign-in**: the native screen has separate Google and Apple actions. Each activates the matching control on DeviantArt's official page and returns to the original OAuth transaction—there is no second sign-in. Mobile uses the desktop layout and keeps the official popup and cookies inside the app.
- **Check proxy before sign-in**: the native screen shows the effective route and provides both proxy settings and a connectivity test before any web page is opened.
- **Human verification**: a proxy exit can trigger DeviantArt's security check. This is not an offline state; complete the check in the current app page and the original authorization flow continues automatically.
- **Blank sign-in page or retry**: back, close, and retry end the current authorization transaction. The next tap creates a fresh PKCE request instead of waiting on an abandoned page; navigation that never starts is stopped after 20 seconds with a recoverable state.
- **Mature content**: DeviantArt account browsing preferences override the app request. Open Settings → DeviantArt account settings → Mature content settings.
- **Settings while sign-in is broken**: the gear on the login screen keeps language, proxy, diagnostics, updates, and About reachable without authentication.
- **macOS Keychain prompt**: on first sign-in or after an upgrade, macOS may ask for your Mac login password once (a normal macOS confirmation for apps outside the App Store). That prompt belongs to macOS and DAViewer never reads the password — it only accesses the DeviantArt token it saved for you.

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
- OAuth authorization runs in the in-app WebView first (reusing the web
  session), with the system browser as a fallback; no account/password form is
  embedded.
