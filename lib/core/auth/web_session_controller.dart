import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/web_session.dart';
import '../runtime/runtime_provider.dart';
import 'auth_controller.dart';
import 'session_state.dart';
import 'web_session_store.dart';

/// Browser state used only by hidden website adapters. It is not a second App
/// identity and must never trigger another login prompt.
final class WebSessionState {
  const WebSessionState({this.csrf = '', this.isLoggedIn, this.username = ''});

  /// CSRF token read from a public page for website-only adapters.
  final String csrf;

  /// Whether the web session is signed in (`null` while unknown).
  final bool? isLoggedIn;

  /// The username signed in on the web (`''` when anonymous).
  final String username;
}

bool shouldStoreBackgroundBrowserSession(String csrf) => csrf.isNotEmpty;

/// Result of a cookie import. [outcome] says what happened; [username]
/// carries the imported session's username on success.
final class CookieImportResult {
  const CookieImportResult(this.outcome, {this.username = ''});

  final CookieImportOutcome outcome;
  final String username;
}

enum CookieImportOutcome {
  /// The cookies carry no DeviantArt `userinfo` session.
  anonymous,

  /// The imported session belongs to a different account than the signed-in
  /// OAuth account or the existing web session.
  accountConflict,

  /// The cookies were injected but DeviantArt did not accept them as the
  /// claimed session.
  verifyFailed,

  /// The platform cookie store is unavailable.
  unavailable,

  /// The session was injected and verified.
  success,
}

/// Identity policy for cookie import. Import is allowed only when there is no
/// signed-in identity at all, or when every existing identity matches the
/// imported session's username. Logging in is the most security-sensitive
/// flow in the app, so a mixed-account import never overwrites an existing
/// session — the user signs out first.
CookieImportOutcome? evaluateCookieImportIdentity({
  required String importedUsername,
  required String? oauthUsername,
  required String currentWebUsername,
}) {
  final imported = importedUsername.trim().toLowerCase();
  if (imported.isEmpty) return CookieImportOutcome.anonymous;
  final oauth = oauthUsername?.trim().toLowerCase() ?? '';
  if (oauth.isNotEmpty && oauth != imported) {
    return CookieImportOutcome.accountConflict;
  }
  final web = currentWebUsername.trim().toLowerCase();
  if (web.isNotEmpty && web != imported) {
    return CookieImportOutcome.accountConflict;
  }
  return null;
}

final webSessionControllerProvider =
    StateNotifierProvider<WebSessionController, WebSessionState>(
      (ref) => WebSessionController(ref),
    );

/// Owns the hidden browser snapshot and prevents a legacy signed-in browser
/// cookie from silently representing a different OAuth account.
final class WebSessionController extends StateNotifier<WebSessionState> {
  WebSessionController(this._ref) : super(const WebSessionState());

  final Ref _ref;
  final WebSessionStore _store = const WebSessionStore();

  Future<void> initialize() async {
    final saved = await _store.read();
    state = WebSessionState(
      csrf: (saved['csrf'] as String?) ?? '',
      isLoggedIn: saved['isLoggedIn'] as bool?,
      username: (saved['username'] as String?) ?? '',
    );
    // The platform WebView store can lose its cookies across an app update;
    // re-inject the persisted copy so the signed-in web session (and with it
    // the personalized feed) survives without asking the user to sign in again.
    await _restoreWebCookies(saved);
  }

  /// Re-injects the persisted deviantart.com cookies when the WebView store
  /// currently has no signed-in `userinfo` cookie. Only restores for a
  /// signed-in OAuth account whose username matches the saved session, so a
  /// signed-out user is never silently given a web session (that would make
  /// the login screen dismiss itself before OAuth completes) and a different
  /// account's cookies are never injected.
  Future<void> _restoreWebCookies(Map<String, Object?> saved) async {
    final rawCookies = saved['cookies'];
    if (rawCookies is! Map || rawCookies.isEmpty) return;
    final savedUsername = (saved['username'] as String?)?.trim() ?? '';
    if (savedUsername.isEmpty) return;
    final oauthUsername = _ref.read(authControllerProvider).account?.username;
    if (oauthUsername == null || oauthUsername.isEmpty) {
      // Not signed in (or the account is still loading): never restore a web
      // session the user has not explicitly re-established.
      return;
    }
    if (savedUsername.toLowerCase() != oauthUsername.toLowerCase()) {
      // Saved web session belongs to a different account; do not restore it.
      return;
    }
    try {
      final currentUser = await _ref.read(webSessionProvider).webUsername();
      if (currentUser.isNotEmpty) return; // Web session already present.
      final cookieManager = _ref
          .read(runtimeProvider)
          .webViewProxyManager
          ?.cookieManager;
      if (cookieManager == null) return;
      for (final entry in rawCookies.entries) {
        if (entry.value is! String) continue;
        await cookieManager.setCookie(
          url: WebUri('https://www.deviantart.com/'),
          name: entry.key,
          value: entry.value as String,
        );
      }
      final restoredUser = await _ref.read(webSessionProvider).webUsername();
      if (restoredUser.isNotEmpty) {
        state = WebSessionState(
          csrf: state.csrf,
          isLoggedIn: true,
          username: restoredUser,
        );
        await _store.write(
          csrf: state.csrf,
          isLoggedIn: true,
          username: restoredUser,
          cookies: _stringMap(rawCookies),
        );
      }
    } on Object {
      // Best effort; a failed restore only means the user signs in again.
    }
  }

  /// Records browser state. A legacy mismatched identity is cleared instead of
  /// being treated as an additional login. A signed-in report also snapshots
  /// the current deviantart.com cookies for later re-injection; an anonymous
  /// refresh keeps the previously saved cookies untouched.
  Future<void> report({required String csrf, required String username}) async {
    final loggedIn = username.isNotEmpty;
    final oauthUsername = _ref.read(authControllerProvider).account?.username;
    if (loggedIn &&
        oauthUsername != null &&
        oauthUsername.isNotEmpty &&
        username.toLowerCase() != oauthUsername.toLowerCase()) {
      try {
        await _ref
            .read(runtimeProvider)
            .webViewProxyManager
            ?.cookieManager
            .deleteAllCookies();
      } on Object {
        // Best effort.
      }
      state = const WebSessionState(isLoggedIn: false);
      await _store.clear();
      return;
    }
    final savedCookies = _stringMap((await _store.read())['cookies']);
    final capturedCookies = loggedIn
        ? await _captureCookies()
        : const <String, String>{};
    // CookieManager can be temporarily unavailable while the platform WebView
    // is starting. Never let that transient empty read destroy the last known
    // good snapshot, or a later app update would have nothing to restore.
    final cookies = selectCookiesForSnapshot(
      loggedIn: loggedIn,
      captured: capturedCookies,
      saved: savedCookies,
    );
    state = WebSessionState(
      csrf: csrf,
      isLoggedIn: loggedIn,
      username: username,
    );
    await _store.write(
      csrf: csrf,
      isLoggedIn: loggedIn,
      username: username,
      cookies: cookies,
    );
  }

  /// Stores a fresh public browser CSRF even without a `userinfo` cookie.
  /// This supports public website metadata fallbacks without asking the user
  /// for a second login after OAuth. An empty CSRF still never overwrites a
  /// valid snapshot.
  Future<void> reportRefresh({
    required String csrf,
    required String username,
  }) async {
    if (!shouldStoreBackgroundBrowserSession(csrf)) return;
    await report(csrf: csrf, username: username);
  }

  /// Snapshots the current deviantart.com cookies (name → value).
  Future<Map<String, String>> _captureCookies() async {
    try {
      final cookieManager = _ref
          .read(runtimeProvider)
          .webViewProxyManager
          ?.cookieManager;
      if (cookieManager == null) return const <String, String>{};
      final cookies = await cookieManager.getCookies(
        url: WebUri('https://www.deviantart.com/'),
      );
      return <String, String>{
        for (final cookie in cookies) cookie.name: cookie.value,
      };
    } on Object {
      return const <String, String>{};
    }
  }

  /// Imports externally provided deviantart.com cookies into the web session
  /// and persists them once DeviantArt confirms the session.
  ///
  /// Identity is checked before anything is written (see
  /// [evaluateCookieImportIdentity]): an import that would create a
  /// mixed-account session is rejected. After injection the imported username
  /// is read back from the cookie store; if it does not match, the previous
  /// cookies are restored so a failed import never leaves a partial or
  /// attacker-controlled session. The caller triggers a CSRF refresh
  /// afterwards so website adapters pick up the new session.
  Future<CookieImportResult> importCookies(Map<String, String> cookies) async {
    final importedUsername = WebSession.usernameFromUserInfo(
      cookies['userinfo'],
    );
    final oauthUsername = _ref.read(authControllerProvider).account?.username;
    String currentWebUsername = '';
    try {
      currentWebUsername = await _ref.read(webSessionProvider).webUsername();
    } on Object {
      // The cookie store may be unavailable; that is handled below.
    }
    final gate = evaluateCookieImportIdentity(
      importedUsername: importedUsername,
      oauthUsername: oauthUsername,
      currentWebUsername: currentWebUsername,
    );
    if (gate != null) {
      return CookieImportResult(gate, username: importedUsername);
    }

    final cookieManager = _ref
        .read(runtimeProvider)
        .webViewProxyManager
        ?.cookieManager;
    if (cookieManager == null) {
      return const CookieImportResult(CookieImportOutcome.unavailable);
    }
    // Snapshot the live cookies so a failed verification can roll back instead
    // of leaving the injected (possibly bad) session in place.
    final previousCookies = await _captureCookies();
    try {
      for (final entry in cookies.entries) {
        await cookieManager.setCookie(
          url: WebUri('https://www.deviantart.com/'),
          name: entry.key,
          value: entry.value,
        );
      }
      final verifiedUser = await _ref.read(webSessionProvider).webUsername();
      final sameAccount =
          verifiedUser.isNotEmpty &&
          verifiedUser.trim().toLowerCase() ==
              importedUsername.trim().toLowerCase();
      if (!sameAccount) {
        await _rollbackCookies(cookieManager, previousCookies);
        return const CookieImportResult(CookieImportOutcome.verifyFailed);
      }
      state = WebSessionState(
        csrf: state.csrf,
        isLoggedIn: true,
        username: verifiedUser,
      );
      await _store.write(
        csrf: state.csrf,
        isLoggedIn: true,
        username: verifiedUser,
        cookies: cookies,
      );
      return CookieImportResult(
        CookieImportOutcome.success,
        username: verifiedUser,
      );
    } on Object {
      await _rollbackCookies(cookieManager, previousCookies);
      return const CookieImportResult(CookieImportOutcome.unavailable);
    }
  }

  /// Restores the live cookie store to [previous] after a failed import.
  Future<void> _rollbackCookies(
    CookieManager cookieManager,
    Map<String, String> previous,
  ) async {
    try {
      await cookieManager.deleteAllCookies();
      for (final entry in previous.entries) {
        await cookieManager.setCookie(
          url: WebUri('https://www.deviantart.com/'),
          name: entry.key,
          value: entry.value,
        );
      }
    } on Object {
      // Best effort; a failed rollback only means the user re-signs-in.
    }
  }

  Future<void> clear() async {
    state = const WebSessionState(isLoggedIn: false);
    await _store.clear();
  }

  /// The persisted deviantart.com cookie snapshot (name → value), used as a
  /// fallback when the live WebView store cannot be read (e.g. cookie export
  /// during early startup). Returns an empty map when nothing is stored.
  Future<Map<String, String>> persistedCookies() async =>
      _stringMap((await _store.read())['cookies']);
}

/// Keeps the last valid cookie snapshot when a signed-in platform read fails.
/// Anonymous refreshes also preserve it; explicit logout still calls [clear].
Map<String, String> selectCookiesForSnapshot({
  required bool loggedIn,
  required Map<String, String> captured,
  required Map<String, String> saved,
}) => loggedIn && captured.isNotEmpty ? captured : saved;

/// Safely converts a decoded JSON value to a string map, dropping anything
/// that is not a string pair.
Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const <String, String>{};
  return <String, String>{
    for (final entry in value.entries)
      if (entry.key is String && entry.value is String)
        entry.key as String: entry.value as String,
  };
}
