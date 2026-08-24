import 'package:daviewer/features/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OAuth-only login lands on a usable official feed', () {
    expect(initialHomeTabIndex(oauthSignedIn: true, webLoggedIn: false), 1);
    expect(initialHomeTabIndex(oauthSignedIn: true, webLoggedIn: null), 1);
    expect(initialHomeTabIndex(oauthSignedIn: true, webLoggedIn: true), 0);
    expect(initialHomeTabIndex(oauthSignedIn: false, webLoggedIn: false), 0);
  });
}
