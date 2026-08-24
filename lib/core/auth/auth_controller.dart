import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/app_logger.dart';
import '../l10n/app_strings.dart';
import '../runtime/app_runtime.dart';
import '../runtime/runtime_provider.dart';
import '../settings/app_preferences.dart';
import 'auth_state.dart';
import 'web_session_controller.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

/// Only the absence/revocation of credentials is allowed to force sign-out.
/// Network, upstream and Keychain failures are recoverable and must not turn a
/// temporarily unreachable persisted session into a destructive first-run
/// experience.
bool shouldPreserveSessionAfterRestoreFailure(Object error) {
  if (error is TimeoutException) return true;
  if (error is! DAKitException) return true;
  if (error.code == 'oauth.session.missing' ||
      error.code == 'oauth.refresh.missing' ||
      error.code.contains('invalid_grant')) {
    return false;
  }
  return true;
}

bool shouldRestoreSignedInAfterFailure({
  required Object error,
  required bool hasSessionEvidence,
}) => hasSessionEvidence && shouldPreserveSessionAfterRestoreFailure(error);

/// Owns the OAuth sign-in lifecycle only. The embedded DeviantArt web session
/// is managed by the separate [WebSessionController].
final class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref)
    : super(const AuthState(status: AuthStatus.unknown));

  final Ref _ref;
  bool _initializing = false;
  bool _loggingIn = false;
  Future<void>? _loginOperation;

  AppRuntime get _runtime => _ref.read(runtimeProvider);
  AppLogger get _log => AppLogger.instance;

  Future<void> initialize() async {
    if (_initializing || state.status != AuthStatus.unknown) return;
    _initializing = true;

    final runtime = _runtime;
    if (runtime.isConfigured && runtime.oauth != null) {
      try {
        // 1. Resume an interrupted OAuth transaction (e.g. cold-start callback
        //    from the system browser). Returns null when there is nothing to
        //    resume, which is the normal case on every regular restart.
        final restored = await runtime.oauth!.resumePending(
          waitForCallback: false,
        );
        if (restored != null) {
          _log.info('auth', 'initialize: resumed pending OAuth login');
          // Sign in immediately; the account profile loads in the background
          // so the splash can hand off to Home without waiting on /user/whoami.
          state = const AuthState(status: AuthStatus.signedIn);
          unawaited(_loadAccount(runtime));
          _initializing = false;
          return;
        }

        // 2. Restore a session persisted by a previous run. Bound the network
        //    round-trips so a slow/hung proxy on cold start can never pin the
        //    splash screen in a "loading forever" state.
        final tokens = await runtime.oauth!
            .validTokens(forceRefresh: false)
            .timeout(const Duration(seconds: 15));
        _log.info(
          'auth',
          'initialize: restored persisted session '
              '(expires ${tokens.expiresAt.toUtc().toIso8601String()})',
        );
        state = const AuthState(status: AuthStatus.signedIn);
        unawaited(_loadAccount(runtime));
        _initializing = false;
        return;
      } on DAKitException catch (error) {
        final hasSessionEvidence = await AppPreferences.loadOAuthSessionKnown();
        if (shouldRestoreSignedInAfterFailure(
          error: error,
          hasSessionEvidence: hasSessionEvidence,
        )) {
          _log.warning(
            'auth',
            'initialize: persisted session temporarily unavailable; '
                'preserving signed-in state',
            error,
          );
          state = const AuthState(status: AuthStatus.signedIn);
          _initializing = false;
          return;
        }
        _log.info(
          'auth',
          hasSessionEvidence
              ? 'initialize: authorization is required'
              : 'initialize: no prior OAuth session; staying signed out',
          error,
        );
      } on Object catch (error, stack) {
        final hasSessionEvidence = await AppPreferences.loadOAuthSessionKnown();
        if (shouldRestoreSignedInAfterFailure(
          error: error,
          hasSessionEvidence: hasSessionEvidence,
        )) {
          _log.warning(
            'auth',
            'initialize: existing session restore failed transiently; '
                'preserving state',
            error,
            stack,
          );
          state = const AuthState(status: AuthStatus.signedIn);
          _initializing = false;
          return;
        }
        _log.warning(
          'auth',
          'initialize: first-run session check failed; staying signed out',
          error,
          stack,
        );
      }
    }

    state = const AuthState(status: AuthStatus.signedOut);
    _initializing = false;
  }

  /// Starts the standard OAuth browser flow.
  Future<void> login() {
    if (state.status == AuthStatus.signedIn) return Future<void>.value();
    final active = _loginOperation;
    if (active != null) return active;

    late final Future<void> tracked;
    tracked = _performLogin().whenComplete(() {
      if (identical(_loginOperation, tracked)) _loginOperation = null;
    });
    _loginOperation = tracked;
    return tracked;
  }

  Future<void> _performLogin() async {
    final runtime = _runtime;
    if (!runtime.isConfigured || runtime.oauth == null) {
      _log.warning('auth', 'OAuth login requires DAKIT_CLIENT_ID');
      state = AuthState(
        status: AuthStatus.signedOut,
        error: strings(_ref.read(appLanguageProvider)).oauthClientIdMissing,
      );
      return;
    }
    if (state.status == AuthStatus.signedIn || _loggingIn) return;

    _loggingIn = true;
    state = AuthState(
      status: state.status,
      account: state.account,
      isLoggingIn: true,
    );
    try {
      _log.info('auth', 'login: starting OAuth authorize');
      await runtime.oauth!.authorize();
      _log.info('auth', 'login: authorize returned, loading account');
      await _loadAccount(runtime);
    } on DAKitException catch (error) {
      if (error.kind == DAKitFailureKind.cancelled ||
          error.code == 'oauth.transaction.cancelled') {
        _log.info('auth', 'OAuth login cancelled cleanly');
        state = const AuthState(status: AuthStatus.signedOut);
        return;
      }
      _log.error('auth', 'OAuth login failed: ${error.code}', error);
      state = AuthState(status: AuthStatus.signedOut, error: error);
    } catch (error, stack) {
      _log.error('auth', 'OAuth login failed (unexpected)', error, stack);
      state = AuthState(status: AuthStatus.signedOut, error: error);
    } finally {
      _loggingIn = false;
    }
  }

  /// Ends an abandoned PKCE transaction and waits until single-flight state is
  /// clear, so the next login creates a new authorize URL immediately.
  Future<void> cancelLogin() async {
    if (state.status == AuthStatus.signedIn) return;
    final runtime = _runtime;
    final active = _loginOperation;
    if (runtime.oauth != null) {
      try {
        await runtime.oauth!.authorization.cancelPending();
      } on Object catch (error, stack) {
        _log.warning(
          'auth',
          'could not cancel pending OAuth login',
          error,
          stack,
        );
      }
    }
    if (active != null) {
      try {
        await active.timeout(const Duration(seconds: 2));
      } on Object {
        // The cancellation signal is authoritative. Do not keep the UI busy
        // merely because an old callback future is slow to unwind.
      }
    }
    _loggingIn = false;
    _loginOperation = null;
    if (state.status != AuthStatus.signedIn) {
      state = const AuthState(status: AuthStatus.signedOut);
    }
  }

  Future<void> logout() async {
    final runtime = _runtime;
    if (runtime.isConfigured && runtime.oauth != null) {
      try {
        _log.info('auth', 'logout: revoking oauth session');
        await runtime.oauth!.logout(revoke: true);
      } on Object catch (error, stack) {
        _log.warning('auth', 'logout: revocation failed', error, stack);
        // Clear the session directly so the next authorize starts clean.
        try {
          await runtime.oauth!.session.logout(revoke: false);
        } on Object catch (error2, stack2) {
          _log.warning('auth', 'logout: token clear failed', error2, stack2);
        }
      }
    }
    // Clear the embedded web session too (cookies + snapshot + state).
    try {
      await runtime.webViewProxyManager?.cookieManager.deleteAllCookies();
    } on Object catch (error, stack) {
      _log.warning('auth', 'logout: web cookie clear failed', error, stack);
    }
    await _ref.read(webSessionControllerProvider.notifier).clear();
    await AppPreferences.saveOAuthSessionKnown(false);
    state = const AuthState(status: AuthStatus.signedOut);
  }

  Future<void> switchAccount() async {
    if (_loggingIn) return;
    _log.info('auth', 'switch account: logout then re-authorize');
    await logout();
    await login();
  }

  Future<void> _loadAccount(AppRuntime runtime) async {
    _log.info('auth', 'loading account');
    try {
      final account = await OfficialAccountRepository(runtime.transport!)
          .currentUser()
          .timeout(const Duration(seconds: 15));
      _log.info('auth', 'account loaded: ${account.username}');
      state = AuthState(status: AuthStatus.signedIn, account: account);
    } on Object catch (error, stack) {
      _log.error('auth', 'account load failed', error, stack);
      // Tokens are still valid even if the profile fetch failed; stay signed
      // in with an unknown profile instead of forcing a logout.
      state = const AuthState(status: AuthStatus.signedIn);
    }
  }
}
