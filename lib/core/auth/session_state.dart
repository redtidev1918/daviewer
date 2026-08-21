import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/web_session.dart';
import '../runtime/runtime_provider.dart';
import 'auth_controller.dart';
import 'auth_state.dart';

/// Reads the DeviantArt web session (Cookie + CSRF).
final webSessionProvider = Provider<WebSession>((ref) {
  final runtime = ref.watch(runtimeProvider);
  final dio = runtime.dio;
  if (dio == null) throw StateError('runtime.dio is not configured');
  return WebSession(dio);
});

/// Whether the DeviantArt web session is signed in (`null` while unknown).
final class WebLoginController extends StateNotifier<bool?> {
  WebLoginController(this._session) : super(null) {
    unawaited(refresh());
  }

  final WebSession _session;

  Future<void> refresh() async {
    try {
      final info = await _session.read();
      state = info.isLoggedIn;
    } on Object {
      // Keep the previous value on transient network errors.
    }
  }
}

final webLoggedInProvider = StateNotifierProvider<WebLoginController, bool?>(
  (ref) => WebLoginController(ref.watch(webSessionProvider)),
);

/// The combined sign-in state — the single source of truth for everything
/// session-dependent (OAuth account + embedded web session).
final class SessionState {
  const SessionState({
    this.oauthStatus = AuthStatus.unknown,
    this.account,
    this.webLoggedIn,
  });

  final AuthStatus oauthStatus;
  final UserProfile? account;
  final bool? webLoggedIn;

  bool get oauthSignedIn => oauthStatus == AuthStatus.signedIn;
}

final sessionStateProvider = Provider<SessionState>((ref) {
  final auth = ref.watch(authControllerProvider);
  final webLoggedIn = ref.watch(webLoggedInProvider);
  return SessionState(
    oauthStatus: auth.status,
    account: auth.account,
    webLoggedIn: webLoggedIn,
  );
});
