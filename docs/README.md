# DAViewer docs

Project documentation index. The user-facing overview lives in the root
[README](../README.md) / [README.en](../README.en.md); the files here cover the
deeper developer and architecture notes.

## Documents

- [Architecture](architecture.md) — SDK/app boundaries, artwork data flow,
  related-content state, gesture ownership, authentication, app-local state,
  and the release contract.
- [Authentication and session recovery](authentication.md) — the two-session
  model, cold-start recovery, Keychain migration, login WebView, and mature
  content settings.
- [Networking and proxy](networking.md) — runtime priority, persisted manual
  settings, WebView coverage by platform, connectivity tests, and recovery.
- [Web adapter](web_adapter.md) — the compatibility contract for the
  reverse-engineered website endpoints (endpoint registry, fallbacks, and the
  change runbook).
- [Build notes](build.md) — pinned toolchain, release/CI contract, and how to
  proxy `pub get` / Gradle builds.
- [Contributing](../CONTRIBUTING.md) — development setup, project structure,
  workflow, and style.

## Convention

- Developer notes are written in English; user-facing copy in the READMEs is
  bilingual (中文 / English).
- Every document should describe current behavior only; historical decisions
  live in [CHANGELOG.md](../CHANGELOG.md) and the release history.
