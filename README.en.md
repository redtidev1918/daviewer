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
- **macOS 12+ unsigned preview**:
  `DAViewer-<version>-macos-unsigned-preview.zip` (universal Intel and Apple
  Silicon build; unzip and drag to Applications)
- **Windows**: `DAViewer-<version>-windows.zip` (unzip and run `DAViewer.exe`)

> **⚠️ macOS unsigned preview:** The macOS artifact has no Apple Developer ID
> signature and has not been notarized by Apple; Keychain may ask for your Mac
> login password. macOS receives that password; DAViewer never reads it. Only
> use the original asset from this repository's Release page.

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
- **Related content**: native "More like this" on the detail page, with clear
  empty and failure states
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
  dakit_core: ^0.1.11
  dakit_api: ^0.1.18
  dakit_flutter: ^0.1.8
```

First sign-in commits the web Cookie/CSRF session before OAuth; signed-out state
is normal onboarding, not a feed error. See
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

The app auto-detects the system proxy at runtime (macOS via `scutil`, Windows via
the registry), or you can set `host:port` manually in Settings → Proxy. The app
also reads `http_proxy`, `https_proxy`, `all_proxy`, and their uppercase forms;
apps launched from Finder usually do not inherit terminal variables — use the
system proxy or in-app settings in that case.

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

When they drift out of sync, a banner at the top of Home offers a one-tap fix.
OAuth authorization happens in the built-in WebView first (reusing the web
session, no password re-entry), falling back to the system browser if the
WebView is unavailable.

## Login FAQ

- **DAViewer has no account of its own**: you sign in with your DeviantArt account — the app never registers an account or stores a password.
- **Forgot your password?** Use the "Forgot Password" link on the login page, or tap "?" → "Forgot password" in the app's login screen to open the reset page in your browser.
- **Register an account**: tap "?" → "Register a DeviantArt account" in the app's login screen to open the sign-up page in your browser.
- **macOS unsigned-preview Keychain prompt**: an ad-hoc-signed app's identity can change between builds, so macOS may ask for the Mac login password on first sign-in or after an upgrade. The password field belongs to macOS and DAViewer never reads it; the app only accesses its own stored DeviantArt OAuth token. The macOS package remains explicitly labelled as an unsigned preview until Developer ID signing and notarization are in place.

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
