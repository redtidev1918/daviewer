# Networking and proxy

DAViewer treats network reachability as an app responsibility. API calls,
media, downloads, web-session refresh, and interactive sign-in must use one
effective route; a raw socket or provider error is never a useful instruction
for the user.

## Selection and persistence

The runtime priority is:

1. a persisted in-app manual proxy;
2. the OS system proxy (`scutil` on macOS, registry on Windows, GNOME settings
   on Linux);
3. `https_proxy`, `http_proxy`, or `all_proxy` (lowercase and uppercase);
4. `DAKIT_PROXY_URL` supplied at build time;
5. direct connection.

The settings screen accepts an HTTP CONNECT proxy as `host:port` or a full URL such as
`http://127.0.0.1:7892`. Clearing it immediately re-runs automatic detection;
it does not retain a stale route. The connectivity test requests DeviantArt
through the effective route with a bounded timeout and reports only an
actionable success/failure message; detailed socket errors stay in Diagnostics.

`export all_proxy=http://127.0.0.1:7892` is useful when launching from a shell.
Finder, Start Menu, and most desktop launchers do not inherit that shell
environment, so release users should prefer a system proxy or the persisted
in-app setting.

## Traffic coverage

| Platform | API / media / downloads | Login and background WebView |
| --- | --- | --- |
| Android | dynamic app proxy | process-wide WebView override |
| Windows | dynamic app proxy | shared WebView2 environment with `--proxy-server` |
| macOS 14+ | dynamic app proxy | `WKWebsiteDataStore.proxyConfigurations` |
| macOS 12/13 | dynamic app proxy | OS system proxy only |
| Linux | dynamic app proxy | OS WebView/system behavior |

All Windows WebViews and cookie reads use the same WebView2 environment. This
is important: creating the login page with one environment and reading cookies
from another makes a successful sign-in appear anonymous.

## Sign-in recovery flow

The login route starts with native UI and does not immediately navigate to a
website. It exposes:

- DeviantArt account sign-in;
- Google / Apple sign-in;
- registration and password recovery (explicit external-browser actions);
- the current effective proxy, proxy settings, and a connectivity test;
- public Settings and Diagnostics routes.

Opening or retrying the official page prepares the WebView route again. A proxy
changed while troubleshooting therefore applies to the newly created browser,
rather than leaving the user in a stale failed WebView.

## Maintainer checks

Before a network-related release:

1. verify direct/automatic/manual selection and clearing;
2. test `all_proxy=http://127.0.0.1:<port>` from a shell;
3. run the in-app connectivity test with a working and stopped proxy;
4. verify both password and social-login WebView navigation;
5. verify the headless web-session refresh uses the same cookie environment;
6. keep raw proxy, HTTP, and parsing details in Diagnostics only.
