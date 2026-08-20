import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../diagnostics/app_logger.dart';
import '../runtime/app_runtime.dart';
import '../runtime/runtime_provider.dart';
import 'auth_state.dart';

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref),
);

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
          await _loadAccount(runtime);
          _initializing = false;
          return;
        }

        // 2. Restore a session persisted by a previous run. validTokens()
        //    reads the secure token store and refreshes an expired token when
        //    possible; it throws oauth.session.missing when nothing is stored.
        final tokens = await runtime.oauth!.validTokens(forceRefresh: false);
        _log.info(
          'auth',
          'initialize: restored persisted session '
          '(expires ${tokens.expiresAt.toUtc().toIso8601String()})',
        );
        await _loadAccount(runtime);
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
      state = const AuthState(
        status: AuthStatus.signedOut,
        error: 'OAuth 登录需要配置 DAKIT_CLIENT_ID。',
      );
      return;
    }
    if (state.status == AuthStatus.signedIn || _loggingIn) return;

    _loggingIn = true;
    state = const AuthState(status: AuthStatus.signedOut);
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

  /// Verifies the configured client id is accepted by DeviantArt by hitting
  /// the authorize endpoint and observing where it redirects. An invalid id
  /// redirects to `redirect_error?error=unauthorized_client`.
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
          message:
              'DAKIT_CLIENT_ID 无效或未在 DeviantArt 注册。\n'
              '请在 deviantart.com/settings/applications 注册一个 '
              'Public OAuth 应用，并把 client_id 通过 '
              '--dart-define=DAKIT_CLIENT_ID=你的ID 传入。',
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
      }
    }
    state = const AuthState(status: AuthStatus.signedOut);
  }

  Future<void> _loadAccount(AppRuntime runtime) async {
    _log.info('auth', 'loading account');
    final account = await OfficialAccountRepository(runtime.transport!)
        .currentUser();
    _log.info('auth', 'account loaded: ${account.username}');
    state = AuthState(
      status: AuthStatus.signedIn,
      account: account,
    );
  }
}
