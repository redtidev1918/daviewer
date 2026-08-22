import 'package:daviewer/core/auth/web_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('personalized feed requires both signed-in identity and CSRF', () {
    expect(const WebSessionState().canLoadPersonalizedFeed, isFalse);
    expect(
      const WebSessionState(
        csrf: 'token',
        isLoggedIn: false,
      ).canLoadPersonalizedFeed,
      isFalse,
    );
    expect(
      const WebSessionState(isLoggedIn: true).canLoadPersonalizedFeed,
      isFalse,
    );
    expect(
      const WebSessionState(
        csrf: 'token',
        isLoggedIn: true,
        username: 'artist',
      ).canLoadPersonalizedFeed,
      isTrue,
    );
  });
}
