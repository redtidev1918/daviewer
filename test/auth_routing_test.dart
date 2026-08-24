import 'package:daviewer/app/router.dart';
import 'package:daviewer/core/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('first-run signed-out state opens login instead of Home', () {
    expect(authRedirect(AuthStatus.signedOut, '/splash'), '/web-login');
  });

  test('restored session leaves splash for Home', () {
    expect(authRedirect(AuthStatus.signedIn, '/splash'), '/');
  });

  test('settings, updates and diagnostics remain available while signed out', () {
    expect(authRedirect(AuthStatus.signedOut, '/settings'), isNull);
    expect(authRedirect(AuthStatus.signedOut, '/settings/proxy'), isNull);
    expect(authRedirect(AuthStatus.signedOut, '/settings/diagnostics'), isNull);
  });

  test('explicit logout returns account routes to public Home', () {
    expect(authRedirect(AuthStatus.signedOut, '/favourites'), '/');
    expect(authRedirect(AuthStatus.signedOut, '/web-login'), isNull);
  });
}
