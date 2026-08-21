# Security Policy

## Supported versions

Only the latest release and `main` are supported. Please upgrade before
reporting an issue.

| Version | Supported |
| ------- | --------- |
| latest release / `main` | :white_check_mark: |
| older releases | :x: |

## Reporting a vulnerability

If you discover a security vulnerability, please **do not** open a public issue.
Email the maintainer directly. Include:

- A description of the issue and its impact.
- Steps to reproduce, or a proof of concept.
- The affected version(s).

You will receive a response and, if the report is valid, a coordinated
disclosure timeline.

## Security posture

- DAViewer is a third-party client and is **not affiliated with DeviantArt**.
- The app ships only a **Public** OAuth `client_id` (no `client_secret` is ever
  stored or distributed).
- OAuth authorization uses Authorization Code + PKCE via DAKit.
- Tokens, cookies, and authorization codes are never logged.
