import 'package:daviewer/core/auth/web_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public browser CSRF is stored without requiring another login', () {
    expect(shouldStoreBackgroundBrowserSession('csrf'), isTrue);
  });

  test('empty background page cannot overwrite the browser session', () {
    expect(shouldStoreBackgroundBrowserSession(''), isFalse);
  });

  test('failed signed-in cookie read preserves the last valid snapshot', () {
    expect(
      selectCookiesForSnapshot(
        loggedIn: true,
        captured: const <String, String>{},
        saved: const <String, String>{'userinfo': 'saved'},
      ),
      const <String, String>{'userinfo': 'saved'},
    );
  });

  test('fresh signed-in cookies replace the saved snapshot', () {
    expect(
      selectCookiesForSnapshot(
        loggedIn: true,
        captured: const <String, String>{'userinfo': 'fresh'},
        saved: const <String, String>{'userinfo': 'saved'},
      ),
      const <String, String>{'userinfo': 'fresh'},
    );
  });

  test('anonymous refresh preserves the signed-in cookie snapshot', () {
    expect(
      selectCookiesForSnapshot(
        loggedIn: false,
        captured: const <String, String>{},
        saved: const <String, String>{'userinfo': 'saved'},
      ),
      const <String, String>{'userinfo': 'saved'},
    );
  });
}
