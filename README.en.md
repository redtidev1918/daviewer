# DAViewer

<p align="center">
  <img src="docs/icon.png" alt="DAViewer" width="160" />
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

## Why

- DeviantArt has discontinued its official client app;
- The website has full functionality (personalized recommendations, galleries,
  tags, favourites, watch, download) but no native desktop/mobile experience;
- This project combines the website's full capabilities with native interaction,
  out of the box — no need to register your own OAuth app.

## Features

- **Sign in**: one login establishes both the web session and OAuth (bundled
  public client id, out of the box, no OAuth app registration needed)
- **Recommendations**: the home "For you" tab is the website's personalized feed
  (`rfy/deviations`), matching the website
- **Search**: keyword search + history + paste a DeviantArt link to jump straight
  to an artwork or artist
- **Artwork detail**: preserves the originating feed so a horizontal swipe or
  top-bar button opens the previous/next work; full-screen images switch works
  only at 1× zoom, while zoomed gestures pan; multi-image works page internally
  first and switch work only after another swipe beyond the first/last page
- **Media**: shared double-tap/pinch image zoom; highest-quality video selection
  with seeking and retry; cached GIFs and rich-text images with progress,
  placeholders, and retry
- **Related content**: native "More like this" results matching the current
  website, with the official API retained as a fallback
- **Tags**: one compact horizontal tag row across detail, search, and tag
  screens; related tags collapse while the artwork feed scrolls down
- **Artist**: profile (including the artist's bio), gallery, **custom
  sub-galleries (folders)**, favourites, watch
- **Social**: favourite artworks (with favourite state), watch/unwatch artists,
  watched-user list, notifications (who posted new work)
- **Download**: verifies original-file access for the current account, explains
  login, purchase, quota, creator, network, and storage failures, and only uses
  an explicitly labelled highest-quality image preview fallback; persistent
  background failure details, file/folder actions, and cleanup confirmation
- **Bilingual**: Chinese / English toggle
- **Proxy**: auto-detect the system proxy + manual configuration (required in
  mainland China)

## Relationship with DAKit

`DAViewer` is the app; DAKit is the SDK. The client only depends on DAKit and
does not copy SDK code. DAKit is published to pub.dev; the client uses versioned
dependencies:

```yaml
dependencies:
  dakit_core: ^0.1.11
  dakit_api: ^0.1.16
  dakit_flutter: ^0.1.8
```

The boundary is explicit: OAuth, official API mapping, domain models, and
background transfers live in DAKit; website-personalized feeds, current website
recommendations, and native page interaction live in DAViewer. Web data is
mapped back into DAKit models, so detail, cache, download, and error handling do
not split into parallel implementations. First sign-in commits the web
Cookie/CSRF before OAuth; signed-out state remains normal onboarding, not a feed
error.

## Install

Download the package for your platform from
[Releases](https://github.com/redtidev1918/daviewer/releases):

- **Android**: `DAViewer-<version>.apk`
- **macOS 12+**: `DAViewer-<version>-macos.zip` (universal Intel and Apple
  Silicon build; unzip and drag to Applications)
- **Windows**: `DAViewer-<version>-windows.zip` (unzip and run `DAViewer.exe`)

> Note: the macOS bundle passes signature-integrity and real launch checks, but
> it is not yet signed with an Apple Developer ID or notarized. On first launch,
> right-click the app and choose Open. If macOS still blocks it, use Open Anyway
> in System Settings → Privacy & Security. Never bypass Gatekeeper for a copy
> obtained from an untrusted source.

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
the registry). To set one manually, enter `host:port` in Settings → Proxy.

`flutter pub get` uses Dart's HTTP client, not the Git proxy; to proxy pub.dev:

```shell
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
# Or use one general proxy (lowercase and uppercase variables are supported):
# export all_proxy=http://127.0.0.1:7892
export no_proxy=localhost,127.0.0.1
flutter pub get
```

DAViewer also reads `http_proxy`, `https_proxy`, `all_proxy`, and their uppercase
forms. Apps launched from Finder usually do not inherit terminal variables; use
the system proxy or Settings → Proxy in that case.

## Release build

Pushes to `main` trigger CI quality checks and Android/macOS/Windows builds;
pushing a `v*` tag creates a GitHub Release and uploads the artifacts (with a
version number, auto-generated changelog, and only the latest release kept).

The macOS CI job reapplies the checked-in release entitlements, verifies the
bundle signature and both CPU architectures, and keeps the built app running
for an eight-second launch smoke test. The artifact remains ad-hoc signed until
Developer ID Application credentials and Apple notarization are configured.

The release APK is always signed with the upload keystore (from the CI
`KEYSTORE_B64` / `KEYSTORE_PROPERTIES` secrets); a release build without a local
`android/key.properties` fails intentionally, to avoid a debug-signed APK that
can't be installed over a previous upload-signed release.

### One-click release (recommended)

Actions → **Release** → Run workflow → pick `patch` / `minor` / `major` (or enter
an exact version) → run. It bumps the version, commits, pushes the tag, and CI
builds and publishes.

Local verification builds:

```shell
flutter build apk --release          # Android APK (requires android/key.properties)
flutter build macos --release        # macOS app
flutter build windows --release      # Windows app
```

## Toolchain

Flutter 3.47 defaults to AGP 9.1.0, but the stable `flutter_inappwebview` (6.1.5)
Android sub-package still references `proguard-android.txt`, which AGP 9 removed,
and its beta macOS sub-package fails to compile under Swift 6. This project
therefore **pins** the following toolchain (off Flutter's defaults, but meeting
Flutter 3.47's Gradle ≥ 8.14 / Kotlin ≥ 2.2.20 minimums):

| Component | Version | Notes |
| --- | --- | --- |
| Android Gradle Plugin | `8.13.2` | 8.x keeps `proguard-android.txt` and supports compileSdk 36 |
| Gradle | `8.14.2` | Flutter 3.47 minimum is 8.14 |
| Kotlin | `2.2.20` | Flutter 3.47 minimum is 2.2.20 |
| flutter_inappwebview | `6.1.5` (exact) | Stable; do not upgrade to `6.2.0-beta` (macOS build fails) |

These values live in `android/settings.gradle.kts`,
`android/gradle/wrapper/gradle-wrapper.properties`, and `pubspec.yaml`. Before
upgrading the plugin or Flutter, verify the `flutter_inappwebview` Android/macOS
sub-packages are compatible with the new AGP/Swift toolchain.

## Project structure

```text
lib/
  main.dart                    App entry, proxy injection, ProviderScope
  app/                         AppShell, theme, router
  core/
    auth/                      Sign-in state, session restore, logout, WebView OAuth bridge
    data/                      Unified data access layer (official API + web fallback)
    diagnostics/               File logging, global error capture
    feed/                      Paged feed controller
    l10n/                      Chinese/English strings and language state
    network/                   Proxy detection, open-in-browser, dynamic proxy Dio
    runtime/                   DAKit composition root
    search/                    Search history persistence
  features/
    login/                     Login page
    home/                      Home (native two tabs: For you / Daily)
    watched/                   Watched feed (first-class "following" tab + avatar strip)
    search/                    Search
    artwork/                   Artwork detail, media playback, download, favourite
    artist/                    Artist profile, gallery, favourites, watch
    favourites/                Current account favourites
    watching/                  Watched users list
    downloads/                 Download list
    settings/                  Settings, proxy, language, logs, about
    diagnostics/               Log & diagnostics page
    splash/                    Splash screen
  shared/widgets/              Shared artwork card, empty/error states
android/
macos/
windows/
test/
```

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
- **You don't need a Google email to register**: DeviantArt accepts any email, and the login page also offers one-click Google / Apple sign-in.
- **Forgot your password?** Use the "Forgot Password" link on the login page, or tap "?" → "Forgot password" in the app's login screen to open the reset page in your browser.
- **Register an account**: tap "?" → "Register a DeviantArt account" in the app's login screen to open the sign-up page in your browser.
- **macOS "Keychain" prompt**: on first sign-in macOS may show a Keychain confirmation. DAViewer stores only the DeviantArt OAuth token in the app's default private Keychain group; it declares no shared Keychain group and never reads or stores browser passwords, Wi-Fi passwords, or other secrets. The item is named "DAViewer".

## Contributing

All contributions are welcome — issues, bug fixes, features, and docs. See
[CONTRIBUTING.md](CONTRIBUTING.md). Report security issues via
[SECURITY.md](SECURITY.md), and see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for
community guidelines.

1. Fork the repository and branch from `main`;
2. Run `flutter analyze` before committing;
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
