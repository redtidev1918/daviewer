# Networking and proxy

DAViewer treats network reachability as an app responsibility. API calls,
media, downloads, web-session refresh, and interactive sign-in must use one
effective route; a raw socket or provider error is never a useful instruction
for the user.

The UI does not geolocate the user or assume that a language equals a country.
It runs a small same-origin reachability check instead: a working direct route
is reported as ready with no proxy pressure, while an unreachable route exposes
the proxy recovery flow. This keeps international and restricted-network
experiences different without collecting location data.

## Selection and persistence

The runtime priority is:

1. a persisted in-app manual proxy;
2. the OS system proxy (`scutil` on macOS, registry on Windows, GNOME manual
   HTTPS/HTTP settings on Linux);
3. `https_proxy`, `http_proxy`, or `all_proxy` (lowercase and uppercase);
4. `DAKIT_PROXY_URL` supplied at build time;
5. direct connection.

The settings screen accepts an HTTP CONNECT proxy as `host:port` or a full URL
such as `http://127.0.0.1:<PORT>`. `<PORT>` is a placeholder, not a DAViewer
default: users must enter the HTTP/Mixed listener shown by their proxy app.
On mobile, `127.0.0.1` means the proxy is running on the same phone. A proxy on
a computer or router requires its LAN IP plus its "allow LAN" option. Clearing
the setting immediately re-runs automatic detection;
it does not retain a stale route. The connectivity test requests DeviantArt
through the effective route with a bounded timeout and reports only an
actionable success/failure message; detailed socket errors stay in Diagnostics.

`export all_proxy=http://127.0.0.1:<PORT>` is useful when launching from a shell
after replacing `<PORT>` with the proxy's real HTTP/Mixed port.
Finder, Start Menu, and most desktop launchers do not inherit that shell
environment, so release users should prefer a system proxy or the persisted
in-app setting.

## Traffic coverage

| Platform | API / media / downloads | Embedded account login | Social login |
| --- | --- | --- | --- |
| Android | system proxy, VPN path, or dynamic app proxy | process-wide WebView override | system browser; system proxy/VPN |
| Windows | dynamic app proxy | shared WebView2 `--proxy-server` | system browser; system proxy/VPN |
| macOS 14+ | dynamic app proxy | `WKWebsiteDataStore.proxyConfigurations` | system browser; system proxy/VPN |
| macOS 12/13 | dynamic app proxy | OS system proxy only | system browser; system proxy/VPN |
| Linux | dynamic app proxy | OS WebView/system behavior | not exposed until packaged callback registration exists |

An in-app manual proxy, shell environment variable, or build define controls
DAViewer clients but cannot reconfigure an already-running external browser.
When one of those app-only sources is active, the login UI warns that social
sign-in additionally requires a working OS proxy or VPN. A system-proxy source
or direct route has no warning. This boundary is deliberate: claiming that an
app-only proxy covers Google in the system browser would be false.

On GNOME, `none` mode ignores stale host/port values and `manual` mode prefers
the HTTPS endpoint before HTTP. PAC `auto` mode is not representable through
`dart:io`'s static `findProxy` directive, so DAViewer logs that limitation and
continues to environment/build/direct fallback instead of claiming that a PAC
route was applied.

All Windows WebViews and cookie reads use the same WebView2 environment. This
is important: creating the login page with one environment and reading cookies
from another makes a successful sign-in appear anonymous.

## Sign-in recovery flow

The login route starts with native UI and does not immediately navigate to a
website. It exposes:

- embedded DeviantArt username/email sign-in using the app route;
- provider-neutral system-browser OAuth for the social providers currently
  shown by DeviantArt (Google, Apple, Facebook at the time of writing);
- registration and password recovery (explicit external-browser actions);
- the current effective proxy, proxy settings, and a connectivity test;
- public Settings and Diagnostics routes.

Opening or retrying the official page prepares the WebView route again. A proxy
changed while troubleshooting therefore applies to the newly created browser,
rather than leaving the user in a stale failed WebView.

Google's OAuth endpoint rejects embedded user-agents, so DAViewer does not
attempt to bypass that policy with a desktop User-Agent or synthetic DOM click.
The external OAuth launch is one-shot: subsequent embedded logins return to the
WebView route. The waiting screen can reopen the same authorize URI or cancel
and clear the pending PKCE state. On Windows, the ZIP build registers the
callback protocol under `HKCU\\Software\\Classes\\dakit` on normal startup and
forwards a callback activation to the existing app process.

Proxy exits can trigger an interactive DeviantArt or edge-provider human
verification document. Such pages may intentionally use HTTP 403, 429, or 503;
the status alone is not a transport failure. The login UI inspects the visible
document and challenge controls, keeps the WebView (including Google/Apple
popups) interactive, and tells the user to finish the check. Network/proxy
recovery is shown only when no challenge document is present. A navigation
generation guard prevents a late inspection from overwriting the next page.
Because modern challenge controls are often inserted after the main document
finishes (or without a `loadStop` event), the active login WebView is also
inspected periodically. HTTP 403/429/503 produces an immediate loading notice;
confirmed controls keep a persistent notice until consecutive clean checks show
that verification has completed. Cookies, DOM storage, third-party cookies, and
the original PKCE transaction remain intact throughout the check.

## Maintainer checks

Before a network-related release:

1. verify direct/automatic/manual selection and clearing;
2. test `all_proxy=http://127.0.0.1:<port>` from a shell;
3. run the in-app connectivity test with a working and stopped proxy;
4. verify embedded password login plus system-browser Google, Apple, and
   Facebook authorization, callback, reopen, cancellation, and a cold-start
   callback;
5. verify a 403/429/503 human-verification document remains interactive and is
   not labelled as a connection failure, including a challenge iframe inserted
   after `loadStop` and one hosted in an embedded popup;
6. verify the headless web-session refresh uses the same cookie environment;
7. on Windows, verify protocol registration, second-process forwarding, and a
   moved release folder;
8. verify an app-only proxy produces the external-browser boundary warning;
9. keep raw proxy, HTTP, and parsing details in Diagnostics only.
