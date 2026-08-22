import 'package:daviewer/features/web_login/web_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OAuth waits until the web login session is committed', () {
    expect(
      shouldStartOAuthAfterWebSession(
        webSignedIn: false,
        oauthSignedIn: false,
        oauthBusy: false,
        alreadyRequested: false,
      ),
      isFalse,
    );
    expect(
      shouldStartOAuthAfterWebSession(
        webSignedIn: true,
        oauthSignedIn: false,
        oauthBusy: false,
        alreadyRequested: false,
      ),
      isTrue,
    );
    expect(
      shouldStartOAuthAfterWebSession(
        webSignedIn: true,
        oauthSignedIn: true,
        oauthBusy: false,
        alreadyRequested: false,
      ),
      isFalse,
    );
  });

  test('only a committed main-frame login 403 is recoverable', () {
    expect(
      shouldRecoverLogin403(
        isMainFrame: true,
        statusCode: 403,
        username: 'signed-in-user',
      ),
      isTrue,
    );
    expect(
      shouldRecoverLogin403(
        isMainFrame: false,
        statusCode: 403,
        username: 'signed-in-user',
      ),
      isFalse,
    );
    expect(
      shouldRecoverLogin403(isMainFrame: true, statusCode: 403, username: ''),
      isFalse,
    );
  });
}
