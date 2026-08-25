import 'package:dakit_core/dakit_core.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// The OAuth sign-in state only. The DeviantArt *web* session lives in the
/// separate [WebSessionState] managed by the web-session controller.
final class AuthState {
  const AuthState({
    required this.status,
    this.account,
    this.error,
    this.isLoggingIn = false,
  });

  final AuthStatus status;
  final UserProfile? account;
  final Object? error;

  /// Whether an OAuth authorization is currently in flight. The login screen
  /// skips auto-starting a new attempt while this is true to avoid a duplicate
  /// authorize transaction.
  final bool isLoggingIn;

  bool get oauthSignedIn => status == AuthStatus.signedIn;
}
