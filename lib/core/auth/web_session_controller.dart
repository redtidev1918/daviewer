import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/runtime_provider.dart';
import 'auth_controller.dart';
import 'web_session_store.dart';

/// The embedded DeviantArt *web* session (Cookie + CSRF + username), kept fully
/// separate from the OAuth account so the two sign-in mechanisms no longer
/// bleed into one another.
final class WebSessionState {
  const WebSessionState({this.csrf = '', this.isLoggedIn, this.username = ''});

  /// CSRF token read from the WebView page, used by the native rfy feed.
  final String csrf;

  /// Whether the web session is signed in (`null` while unknown).
  final bool? isLoggedIn;

  /// The username signed in on the web (`''` when anonymous).
  final String username;

  bool get signedIn => isLoggedIn == true;

  /// A personalized feed request is valid only after both identity and CSRF
  /// restoration have completed. Signed-out/unknown state is normal UI state,
  /// not a request failure.
  bool get canLoadPersonalizedFeed => signedIn && csrf.isNotEmpty;
}

bool shouldCommitBackgroundWebSession({
  required String csrf,
  required String username,
}) => csrf.isNotEmpty && username.isNotEmpty;

final webSessionControllerProvider =
    StateNotifierProvider<WebSessionController, WebSessionState>(
      (ref) => WebSessionController(ref),
    );

/// Owns the web-session lifecycle: restoring the persisted snapshot, accepting
/// reports from the WebView, reconciling against the OAuth account (so two
/// accounts never coexist), and persisting the snapshot for cold starts.
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

  /// Records the web session read from the WebView and reconciles it with the
  /// OAuth account: a mismatched username clears the web cookies so the app
  /// never shows two accounts at once.
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

  /// Accepts a background refresh only when it positively identifies an
  /// account. A bot-check, partial page or network error can expose a CSRF but
  /// omit the `userinfo` cookie; that is not proof the user signed out and must
  /// never overwrite a valid persisted session.
  Future<void> reportRefresh({
    required String csrf,
    required String username,
  }) async {
    if (!shouldCommitBackgroundWebSession(csrf: csrf, username: username)) {
      return;
    }
    await report(csrf: csrf, username: username);
  }

  Future<void> clear() async {
    state = const WebSessionState(isLoggedIn: false);
    await _store.clear();
  }
}
