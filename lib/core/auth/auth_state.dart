import 'package:dakit_core/dakit_core.dart';

enum AuthStatus { unknown, signedOut, signedIn }

final class AuthState {
  const AuthState({required this.status, this.account, this.error});

  final AuthStatus status;
  final UserProfile? account;
  final Object? error;
}
