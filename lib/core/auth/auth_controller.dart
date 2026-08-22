import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/app_logger.dart';
import '../l10n/app_strings.dart';
import '../runtime/app_runtime.dart';
import '../runtime/runtime_provider.dart';
import 'auth_state.dart';
import 'web_session_controller.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

/// Owns the OAuth sign-in lifecycle only. The embedded DeviantArt web session
/// is managed by the separate [WebSessionController].
final class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref)
    : super(const AuthState(status: AuthStatus.unknown));

  final Ref _ref;
  bool _initializing = false;
  bool _loggingIn = false;

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
        _log.warning('auth', 'initialize: no usable oauth session', error);
      } on Object catch (error, stack) {
        _log.error('auth', 'initialize: oauth error', error, stack);
      }
    }

    state = const AuthState(status: AuthStatus.signedOut);
    _initializing = false;
  }

  /// Starts the standard OAuth browser flow.
  Future<void> login() async {
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
      await _preflightClientId(runtime);
      _log.info('auth', 'login: starting OAuth authorize');
      await runtime.oauth!.authorize();
      _log.info('auth', 'login: authorize returned, loading account');
      await _loadAccount(runtime);
    } on DAKitException catch (error) {
      _log.error('auth', 'OAuth login failed: ${error.code}', error);
      state = AuthState(status: AuthStatus.signedOut, error: error);
    } catch (error, stack) {
      _log.error('auth', 'OAuth login failed (unexpected)', error, stack);
      state = AuthState(status: AuthStatus.signedOut, error: error);
    } finally {
      _loggingIn = false;
    }
  }

  /// Verifies the configured client id is accepted by DeviantArt.
  Future<void> _preflightClientId(AppRuntime runtime) async {
    final dio = runtime.dio;
    if (dio == null) return;
    final authorize = Uri.https(
      'www.deviantart.com',
      '/oauth2/authorize',
      <String, String>{
        'response_type': 'code',
        'client_id': runtime.clientId,
        'redirect_uri': 'dakit://oauth/callback',
      },
    );
    try {
      final response = await dio.getUri<Object?>(
        authorize,
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final location = response.headers.value('location') ?? '';
      if (location.contains('redirect_error') ||
          location.contains('unauthorized_client') ||
          location.contains('invalid_client')) {
        _log.error('auth', 'client id rejected by DeviantArt: $location');
        throw DAKitException(
          kind: DAKitFailureKind.configuration,
          code: 'oauth.client_id.invalid',
          message: strings(_ref.read(appLanguageProvider)).oauthClientIdInvalid,
          details: <String, Object?>{'location': location},
        );
      }
      _log.info(
        'auth',
        'client id preflight ok (status=${response.statusCode})',
      );
    } on DAKitException {
      rethrow;
    } on Object catch (error, stack) {
      // Preflight is best-effort; a network hiccup should not block login.
      _log.warning('auth', 'client id preflight skipped', error, stack);
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
      await CookieManager.instance().deleteAllCookies();
    } on Object catch (error, stack) {
      _log.warning('auth', 'logout: web cookie clear failed', error, stack);
    }
    await _ref.read(webSessionControllerProvider.notifier).clear();
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
