import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  AppRuntime get _runtime => _ref.read(runtimeProvider);

  Future<void> initialize() async {
    if (_initializing || state.status != AuthStatus.unknown) return;
    _initializing = true;

    final runtime = _runtime;
    if (!runtime.isConfigured) {
      state = const AuthState(
        status: AuthStatus.signedOut,
        error: 'Pass DAKIT_CLIENT_ID at build time.',
      );
      _initializing = false;
      return;
    }

    try {
      await runtime.oauth!.resumePending(waitForCallback: false);
      await runtime.oauth!.validTokens(forceRefresh: false);
      await _loadAccount(runtime);
    } on DAKitException catch (error) {
      if (error.code == 'oauth.session.missing') {
        state = const AuthState(status: AuthStatus.signedOut);
      } else {
        state = AuthState(status: AuthStatus.signedOut, error: error);
      }
    } catch (error) {
      state = AuthState(status: AuthStatus.signedOut, error: error);
    } finally {
      _initializing = false;
    }
  }

  Future<void> login() async {
    final runtime = _runtime;
    if (!runtime.isConfigured) {
      state = const AuthState(
        status: AuthStatus.signedOut,
        error: 'Pass DAKIT_CLIENT_ID at build time.',
      );
      return;
    }
    if (state.status == AuthStatus.signedIn) return;

    state = const AuthState(status: AuthStatus.signedOut);
    try {
      await runtime.oauth!.authorize();
      await _loadAccount(runtime);
    } on DAKitException catch (error) {
      state = AuthState(status: AuthStatus.signedOut, error: error);
    } catch (error) {
      state = AuthState(status: AuthStatus.signedOut, error: error);
    }
  }

  Future<void> logout() async {
    final runtime = _runtime;
    if (runtime.isConfigured) {
      try {
        await runtime.oauth!.logout(revoke: true);
      } on Object {
        // Local state must clear even when remote revocation fails.
      }
    }
    state = const AuthState(status: AuthStatus.signedOut);
  }

  Future<void> _loadAccount(AppRuntime runtime) async {
    final account = await OfficialAccountRepository(runtime.transport!)
        .currentUser();
    state = AuthState(status: AuthStatus.signedIn, account: account);
  }
}
