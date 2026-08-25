import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/runtime_provider.dart';
import 'auth_controller.dart';
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
  }

  /// Records browser state. A legacy mismatched identity is cleared instead of
  /// being treated as an additional login.
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
    state = WebSessionState(
      csrf: csrf,
      isLoggedIn: loggedIn,
      username: username,
    );
    await _store.write(csrf: csrf, isLoggedIn: loggedIn, username: username);
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

  Future<void> clear() async {
    state = const WebSessionState(isLoggedIn: false);
    await _store.clear();
  }
}
