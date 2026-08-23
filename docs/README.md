# DAViewer docs

Project documentation index. The user-facing overview lives in the root
[README](../README.md) / [README.en](../README.en.md); the files here cover the
deeper developer and architecture notes.

## Documents

- [Architecture](architecture.md) — SDK/app boundaries, artwork data flow,
  related-content state, gesture ownership, authentication, app-local state,
  and the release contract.
- [Build notes](build.md) — pinned toolchain, release/CI contract, and how to
  proxy `pub get` / Gradle builds.
- [Contributing](../CONTRIBUTING.md) — development setup, project structure,
  workflow, and style.

## Convention

- Developer notes are written in English; user-facing copy in the READMEs is
  bilingual (中文 / English).
- Every document should describe current behavior only; historical decisions
  live in [CHANGELOG.md](../CHANGELOG.md) and the release history.
