# DAViewer

**Language:** English · [中文](README.md)

> DeviantArt abandoned their official app, and the community was left without a
> good third-party client — so **DAViewer** exists. An open-source DeviantArt
> client built on [DAKit](https://github.com/redtidev1918/dakit), bringing the
> website's experience back to desktop and mobile.

[![GitHub stars](https://img.shields.io/github/stars/redtidev1918/daviewer?style=flat&color=yellow)](https://github.com/redtidev1918/daviewer/stargazers)
[![GitHub license](https://img.shields.io/github/license/redtidev1918/daviewer?style=flat)](LICENSE)
[![GitHub release](https://img.shields.io/github/v/release/redtidev1918/daviewer?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20macOS%20%7C%20Windows-blue?style=flat)](https://github.com/redtidev1918/daviewer/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.1-blue?style=flat&logo=flutter)](https://flutter.dev)

## Why

- DeviantArt has **discontinued/abandoned** its official client app, and most
  third-party tools are stale;
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
- **Artwork detail**: images / video (seekable) / GIF playback, swipe through
  multi-image galleries, full rich-text description (links / bold / emotes /
  embedded images)
- **Related content**: "More like this" waterfall plus "Featured in / Suggested
  collections" card rails at the bottom of the detail page
- **Tags**: `#tags` on the detail page, tap through to the tag feed, plus
  "related tags" on the tag page
- **Artist**: profile (including the artist's bio), gallery, **custom
  sub-galleries (folders)**, favourites, watch
- **Social**: favourite artworks (with favourite state), watch/unwatch artists,
  watched-user list, notifications (who posted new work)
- **Download**: original-file background download with full-size preview
  fallback when restricted; download list with open file/folder
- **Bilingual**: Chinese / English toggle
- **Proxy**: auto-detect the system proxy + manual configuration (required in
  mainland China)

## Relationship with DAKit

`DAViewer` is the app; DAKit is the SDK. The client only depends on DAKit and
does not copy SDK code. DAKit is published to pub.dev; the client uses versioned
dependencies:

```yaml
dependencies:
  dakit_flutter: ^0.1.0
```

## Install

Download the package for your platform from
[Releases](https://github.com/redtidev1918/daviewer/releases):

- **Android**: `DAViewer-<version>.apk`
- **macOS**: `DAViewer-<version>-macos.zip` (unzip and drag to Applications)
- **Windows**: `DAViewer-<version>-windows.zip` (unzip and run `DAViewer.exe`)

> Note: the macOS app is unsigned. On first launch, right-click → Open, or allow
> it in System Settings → Privacy & Security.

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
export no_proxy=localhost,127.0.0.1
flutter pub get
```

## Release build

Pushes to `main` trigger CI quality checks and Android/macOS/Windows builds;
pushing a `v*` tag creates a GitHub Release and uploads the artifacts (with a
version number, auto-generated changelog, and only the latest release kept).

The release APK is always signed with the upload keystore (from the CI
`KEYSTORE_B64` / `KEYSTORE_PROPERTIES` secrets); a release build without a local
`android/key.properties` fails intentionally, to avoid a debug-signed APK that
can't be installed over a previous upload-signed release.

### One-click release (recommended)

Actions → **Release** → Run workflow → pick `patch` / `minor` / `major` (or enter
an exact version) → run. It bumps the version, commits, pushes the tag, and CI
builds and publishes.

### Manual release

```shell
# 1. Update `version` in pubspec.yaml and `versionLabel` in
#    lib/features/settings/settings_screen.dart
# 2. Commit and push
# 3. Push a tag to trigger the release
git tag v0.2.42 && git push origin v0.2.42   # replace with the actual version
```

Local builds:

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
- **macOS "Keychain" prompt**: on first sign-in macOS may show "DAViewer wants to use confidential information stored in your keychain". This is the standard confirmation macOS shows for *any* app that keeps its own login credentials in Keychain. DAViewer stores only the OAuth token it received after you signed in to DeviantArt — it never reads or stores other secrets (browser passwords, Wi-Fi, etc.). The item is named "DAViewer" and the sandboxed app declares its keychain access, so you shouldn't see repeated prompts.

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
