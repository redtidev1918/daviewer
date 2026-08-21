# Contributing to DAViewer

Thanks for wanting to help! DAViewer is a community client for DeviantArt built
on [DAKit](https://github.com/redtidev1918/dakit). Contributions of any size are
welcome — bug reports, fixes, features, translations, and documentation.

## Before you start

- **SDK vs app**: DAViewer is the app; [DAKit](https://github.com/redtidev1918/dakit)
  is the SDK it depends on. If a change belongs in the SDK (API adapters, OAuth,
  domain models, transfers), open the PR over there and publish it first, then
  bump the dependency here.
- Search existing [issues](https://github.com/redtidev1918/daviewer/issues) and
  PRs before opening a new one.
- For security issues, see [SECURITY.md](SECURITY.md) and do **not** file them
  publicly.

## Development setup

1. Install Flutter 3.47.1 (the project pins this version).
2. `flutter pub get`
3. Run `flutter analyze` before committing — it must be clean.
4. For a full build, see the [README](README.md#构建-release--release-build).

> The project deliberately pins `flutter_inappwebview 6.1.5` and specific
> Gradle/AGP/Kotlin versions (see the README's toolchain table). Do not upgrade
> these without verifying the toolchain compatibility.

## Workflow

1. Fork the repository and create a branch from `main`.
2. Make your change. Keep commits focused and descriptive.
3. `flutter analyze` and `flutter test` locally.
4. Open a pull request. Explain **what** changed and **why**.

## Style

- Follow the existing code style; run `dart format lib` before committing.
- Keep user-facing strings in `lib/core/l10n/app_strings.dart` (Chinese + English).
- Prefer small, reviewable PRs over large, mixed ones.

## Getting help

Open an issue with the `question` label, or start a discussion. Maintainers and
the community will help you get unblocked.
