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

  test('explicit logout returns protected routes to public Home', () {
    expect(authRedirect(AuthStatus.signedOut, '/settings'), '/');
    expect(authRedirect(AuthStatus.signedOut, '/web-login'), isNull);
  });
}
