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
    this.webCsrf = '',
    this.webUsername = '',
    this.isLoggingIn = false,
  });

  final AuthStatus status;
  final UserProfile? account;
  final Object? error;

  /// Whether the DeviantArt web session is signed in (`null` while unknown).
  final bool? webLoggedIn;

  /// The CSRF token read from the embedded web page, used by the native
  /// `rfy/deviations` feed.
  final String webCsrf;

  /// The username signed in on the web (`''` when anonymous or unknown).
  final String webUsername;

  /// Whether an OAuth authorization is currently in flight. The UI suppresses
  /// the login-sync banner while this is true to avoid a transient "web signed
  /// in, complete app login" flash during the normal login flow.
  final bool isLoggingIn;

  bool get oauthSignedIn => status == AuthStatus.signedIn;
}
