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

  test(
    'human-verification pages are not classified as connection failures',
    () {
      expect(
        looksLikeHumanVerificationPage(
          title: 'Security verification',
          visibleText: 'Press & Hold to confirm you are a human',
        ),
        isTrue,
      );
      expect(
        looksLikeHumanVerificationPage(
          pageUri: Uri.parse(
            'https://www.deviantart.com/_sec/cp_challenge/verify',
          ),
        ),
        isTrue,
      );
      expect(
        looksLikeHumanVerificationPage(
          title: 'Log in | DeviantArt',
          visibleText: 'Log in with your username or email and password.',
        ),
        isFalse,
      );

      expect(
        classifyLoginHttpPage(
          isMainFrame: true,
          statusCode: 403,
          username: '',
          isHumanVerification: true,
        ),
        LoginHttpPageKind.humanVerification,
      );
      expect(
        classifyLoginHttpPage(
          isMainFrame: true,
          statusCode: 403,
          username: '',
          isHumanVerification: false,
        ),
        LoginHttpPageKind.connectionFailure,
      );
    },
  );

  test('edge throttling statuses can carry an interactive challenge', () {
    expect(isPotentialHumanVerificationStatus(403), isTrue);
    expect(isPotentialHumanVerificationStatus(429), isTrue);
    expect(isPotentialHumanVerificationStatus(503), isTrue);
    expect(isPotentialHumanVerificationStatus(500), isFalse);
    expect(
      classifyLoginHttpPage(
        isMainFrame: true,
        statusCode: 503,
        username: '',
        isHumanVerification: true,
      ),
      LoginHttpPageKind.humanVerification,
    );
  });

  test('social sign-in resumes the same OAuth transaction only from login', () {
    expect(
      shouldResumeOAuthAfterSocialSignIn(
        method: WebLoginMethod.google,
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse(
          'https://www.deviantart.com/users/login?referer=oauth2',
        ),
      ),
      isTrue,
    );
    expect(
      shouldResumeOAuthAfterSocialSignIn(
        method: WebLoginMethod.google,
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse(
          'https://www.deviantart.com/join?oauth=1&referer=oauth2',
        ),
      ),
      isTrue,
    );
    expect(
      shouldResumeOAuthAfterSocialSignIn(
        method: WebLoginMethod.google,
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse('https://www.deviantart.com/oauth2/authorize'),
      ),
      isFalse,
    );
    expect(
      shouldResumeOAuthAfterSocialSignIn(
        method: WebLoginMethod.google,
        oauthSignedIn: false,
        callbackSeen: true,
        mainFrameUri: Uri.parse('https://www.deviantart.com/users/login'),
      ),
      isFalse,
    );
    expect(
      shouldResumeOAuthAfterSocialSignIn(
        method: WebLoginMethod.deviantArt,
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse('https://www.deviantart.com/users/login'),
      ),
      isFalse,
    );
  });

  test(
    'native login choices target distinct controls on OAuth entry pages',
    () {
      final join = Uri.parse(
        'https://www.deviantart.com/join?oauth=1&referer=oauth2',
      );
      final login = Uri.parse('https://www.deviantart.com/users/login');
      final authorize = Uri.parse(
        'https://www.deviantart.com/oauth2/authorize',
      );

      expect(
        shouldActivateLoginMethod(
          method: WebLoginMethod.deviantArt,
          alreadyActivated: false,
          pageUri: join,
        ),
        isTrue,
      );
      expect(
        shouldActivateLoginMethod(
          method: WebLoginMethod.deviantArt,
          alreadyActivated: false,
          pageUri: login,
        ),
        isFalse,
      );
      expect(
        shouldActivateLoginMethod(
          method: WebLoginMethod.google,
          alreadyActivated: false,
          pageUri: join,
        ),
        isTrue,
      );
      expect(
        shouldActivateLoginMethod(
          method: WebLoginMethod.apple,
          alreadyActivated: false,
          pageUri: login,
        ),
        isTrue,
      );
      expect(
        shouldActivateLoginMethod(
          method: WebLoginMethod.google,
          alreadyActivated: false,
          pageUri: authorize,
        ),
        isFalse,
      );
    },
  );
}
