import 'package:daviewer/features/web_login/web_login_screen.dart';
import 'package:daviewer/core/network/proxy_controller.dart';
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

  test('a new login screen replaces an abandoned OAuth transaction', () {
    expect(
      shouldReplaceAbandonedOAuth(authBusy: true, requestedByThisScreen: false),
      isTrue,
    );
    expect(
      shouldReplaceAbandonedOAuth(authBusy: true, requestedByThisScreen: true),
      isFalse,
    );
    expect(
      shouldReplaceAbandonedOAuth(
        authBusy: false,
        requestedByThisScreen: false,
      ),
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
          pageUri: Uri.parse(
            'https://challenges.cloudflare.com/turnstile/v0/g/abc',
          ),
        ),
        isTrue,
      );
      expect(
        looksLikeHumanVerificationPage(
          pageUri: Uri.parse('https://client-api.arkoselabs.com/fc/gc/'),
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
        looksLikeHumanVerificationPage(
          pageUri: Uri.parse(
            'https://www.deviantart.com/oauth2/authorize?response_type=code&code_challenge=pkce-value&code_challenge_method=S256',
          ),
          title: 'Authorize application',
          visibleText: 'Allow this application to access your account.',
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
    expect(
      classifyLoginHttpPage(
        isMainFrame: true,
        statusCode: 429,
        username: '',
        isHumanVerification: false,
      ),
      LoginHttpPageKind.connectionFailure,
    );
    expect(
      classifyLoginHttpPage(
        isMainFrame: true,
        statusCode: 503,
        username: '',
        isHumanVerification: false,
      ),
      LoginHttpPageKind.connectionFailure,
    );
  });

  test('human-verification state survives loading and clears after proof', () {
    expect(
      humanVerificationStateAfterHttpStatus(
        current: HumanVerificationState.none,
        statusCode: 403,
      ),
      HumanVerificationState.loading,
    );
    expect(
      humanVerificationStateAfterInspection(
        current: HumanVerificationState.loading,
        detected: true,
        consecutiveCleanObservations: 0,
      ),
      HumanVerificationState.active,
    );
    expect(
      humanVerificationStateAfterInspection(
        current: HumanVerificationState.active,
        detected: false,
        consecutiveCleanObservations: 1,
      ),
      HumanVerificationState.active,
    );
    expect(
      humanVerificationStateAfterInspection(
        current: HumanVerificationState.active,
        detected: false,
        consecutiveCleanObservations: 2,
      ),
      HumanVerificationState.none,
    );
    expect(
      humanVerificationStateAfterHttpStatus(
        current: HumanVerificationState.none,
        statusCode: 500,
      ),
      HumanVerificationState.none,
    );
  });

  test('embedded provider completion resumes the same OAuth transaction only from login', () {
    expect(
      shouldResumeOAuthAfterEmbeddedProvider(
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse(
          'https://www.deviantart.com/users/login?referer=oauth2',
        ),
      ),
      isTrue,
    );
    expect(
      shouldResumeOAuthAfterEmbeddedProvider(
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse(
          'https://www.deviantart.com/join?oauth=1&referer=oauth2',
        ),
      ),
      isTrue,
    );
    expect(
      shouldResumeOAuthAfterEmbeddedProvider(
        oauthSignedIn: false,
        callbackSeen: false,
        mainFrameUri: Uri.parse('https://www.deviantart.com/oauth2/authorize'),
      ),
      isFalse,
    );
    expect(
      shouldResumeOAuthAfterEmbeddedProvider(
        oauthSignedIn: false,
        callbackSeen: true,
        mainFrameUri: Uri.parse('https://www.deviantart.com/users/login'),
      ),
      isFalse,
    );
  });

  test('embedded account route only activates the DeviantArt join control', () {
    final join = Uri.parse(
      'https://www.deviantart.com/join?oauth=1&referer=oauth2',
    );
    final login = Uri.parse('https://www.deviantart.com/users/login');
    final authorize = Uri.parse('https://www.deviantart.com/oauth2/authorize');

    expect(
      shouldActivateDeviantArtAccountForm(
        alreadyActivated: false,
        pageUri: join,
      ),
      isTrue,
    );
    expect(
      shouldActivateDeviantArtAccountForm(
        alreadyActivated: false,
        pageUri: login,
      ),
      isFalse,
    );
    expect(
      shouldActivateDeviantArtAccountForm(
        alreadyActivated: false,
        pageUri: authorize,
      ),
      isFalse,
    );
    expect(
      shouldActivateDeviantArtAccountForm(
        alreadyActivated: true,
        pageUri: join,
      ),
      isFalse,
    );
  });

  test('system browser proxy warning matches the actual routing boundary', () {
    expect(systemBrowserFollowsSelectedProxy(ProxySource.system), isTrue);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.direct), isTrue);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.manual), isFalse);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.environment), isFalse);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.dartDefine), isFalse);
  });

  test('official social providers are discovered without treating other aria labels as login methods', () {
    const html = '''
      <button aria-label="Search">Search</button>
      <div aria-label="Google"></div>
      <button aria-label="Apple"><div>Continue with Apple</div></button>
      <button aria-label="Facebook"><div>Continue with Facebook</div></button>
      <button aria-label="close">Close</button>
    ''';

    expect(discoverOfficialSocialProviders(html), <String>[
      'Google',
      'Apple',
      'Facebook',
    ]);
    expect(
      discoverOfficialSocialProviders('<form>email and password</form>'),
      isEmpty,
    );
  });
}
