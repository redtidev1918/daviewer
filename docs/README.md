# DAViewer docs

Project documentation index. The user-facing overview lives in the root
[README](../README.md) / [README.en](../README.en.md); the files here cover the
deeper developer and architecture notes.

## Documents

- [Architecture](architecture.md) — SDK/app boundaries, artwork data flow,
  related-content state, gesture ownership, authentication, app-local state,
  and the release contract.
- [Authentication and session recovery](authentication.md) — the single-OAuth
  model, cold-start recovery, macOS credential storage, and mature-content settings.
- [Networking and proxy](networking.md) — runtime priority, persisted manual
  settings, WebView coverage by platform, connectivity tests, and recovery.
- [Web adapter](web_adapter.md) — the compatibility contract for the
  reverse-engineered website endpoints (endpoint registry, fallbacks, and the
  change runbook).
- [Build notes](build.md) — pinned toolchain, release/CI contract, and how to
  proxy `pub get` / Gradle builds.
- [Contributing](../CONTRIBUTING.md) — development setup, project structure,
  workflow, and style.

## Related

- [DAKit documentation](https://github.com/redtidev1918/dakit/blob/main/docs/README.md)
  — the upstream SDK this app depends on (OAuth, official API mapping, domain
  models, background transfers). SDK-level questions belong there.

## Convention

- Developer notes are written in English; user-facing copy in the READMEs is
  bilingual (中文 / English).
- Every document should describe current behavior only; historical decisions
  live in [CHANGELOG.md](../CHANGELOG.md) and the release history.
