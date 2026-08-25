# DAViewer build notes

Toolchain, release, and build-proxy details that are too deep for the README.

## Toolchain pin

Flutter 3.47 defaults to AGP 9.1.0, but the stable `flutter_inappwebview` (6.1.5)
Android sub-package still references `proguard-android.txt`, which AGP 9 removed,
and its beta macOS sub-package fails to compile under Swift 6. This project
therefore pins the following toolchain (meeting Flutter 3.47's Gradle ≥ 8.14 /
Kotlin ≥ 2.2.20 minimums):

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

## Release contract

- Pushes to `main` trigger CI quality checks and Android/macOS/Windows builds;
  pushing a `v*` tag creates a GitHub Release whose notes come from the matching
  user-facing `RELEASE_NOTES.md` section. A missing section blocks the release
  instead of exposing commit messages or internal implementation notes.
- The release APK is always signed with the upload keystore (CI
  `KEYSTORE_B64` / `KEYSTORE_PROPERTIES` secrets); a release build without a
  local `android/key.properties` fails intentionally, so a debug-signed APK can
  never be installed over a previous upload-signed release.
- The macOS CI job reapplies the checked-in release entitlements, verifies the
  ad-hoc signature and both CPU architectures, and keeps the built app running
  for an eight-second launch smoke test. Artifacts are named
  `macos-unsigned-preview`; that marker can only be removed after Developer ID
  Application signing, Hardened Runtime, and Apple notarization are configured.

### One-click release

Actions → **Release** → Run workflow → pick `patch` / `minor` / `major` (or an
exact version) → run. It bumps the version, commits, pushes the tag, and CI
builds and publishes.

Local verification builds:

```shell
flutter build apk --release          # Android APK (requires android/key.properties)
flutter build macos --release        # macOS app
flutter build windows --release      # Windows app
```

## Proxying builds

`flutter pub get` uses Dart's HTTP client, not the Git proxy:

```shell
export http_proxy=http://127.0.0.1:7890
export https_proxy=http://127.0.0.1:7890
# Or one general proxy (lowercase and uppercase variables are supported):
# 7892 is only an example; replace it with your proxy's HTTP/Mixed port.
# export all_proxy=http://127.0.0.1:7892
export no_proxy=localhost,127.0.0.1
flutter pub get
```

The Gradle Wrapper runs on the JVM and is not guaranteed to read `all_proxy`.
Pass JVM proxy properties explicitly when an Android toolchain download needs a
proxy:

```shell
# Replace 7892 with the actual HTTP/Mixed port shown by your proxy app.
export GRADLE_OPTS="-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=7892 -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=7892"
flutter build apk --debug
```
