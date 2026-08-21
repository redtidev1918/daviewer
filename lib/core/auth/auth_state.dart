import 'package:dakit_core/dakit_core.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// The single sign-in state: the OAuth account plus the embedded DeviantArt
/// web session. Both are kept here so the whole app reacts to one state.
final class AuthState {
  const AuthState({
    required this.status,
    this.account,
    this.error,
    this.webLoggedIn,
  });

  final AuthStatus status;
  final UserProfile? account;
  final Object? error;

  /// Whether the DeviantArt web session is signed in (`null` while unknown).
  final bool? webLoggedIn;

  bool get oauthSignedIn => status == AuthStatus.signedIn;
}
