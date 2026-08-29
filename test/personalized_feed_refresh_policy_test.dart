import 'package:daviewer/core/auth/web_session_controller.dart';
import 'package:daviewer/features/home/home_providers.dart';
import 'package:daviewer/features/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('personalized feed session identity', () {
    test('ignores CSRF rotation', () {
      const before = WebSessionState(
        csrf: 'old-token',
        isLoggedIn: true,
        username: 'sample',
      );
      const after = WebSessionState(
        csrf: 'new-token',
        isLoggedIn: true,
        username: 'sample',
      );

      expect(
        personalizedFeedSessionIdentity(after),
        personalizedFeedSessionIdentity(before),
      );
    });

    test('changes when the signed-in identity changes', () {
      const signedOut = WebSessionState(isLoggedIn: false);
      const signedIn = WebSessionState(
        csrf: 'token',
        isLoggedIn: true,
        username: 'sample',
      );

      expect(
        personalizedFeedSessionIdentity(signedIn),
        isNot(personalizedFeedSessionIdentity(signedOut)),
      );
    });
  });

  group('personalized feed foreground refresh', () {
    bool shouldRefresh({
      Duration backgroundDuration = const Duration(minutes: 10),
      bool routeIsCurrent = true,
      bool recommendedTabIsActive = true,
      double scrollOffset = 0,
    }) => shouldRefreshPersonalizedFeedOnResume(
      backgroundDuration: backgroundDuration,
      routeIsCurrent: routeIsCurrent,
      recommendedTabIsActive: recommendedTabIsActive,
      scrollOffset: scrollOffset,
    );

    test('refreshes a stale visible recommendation feed near the top', () {
      expect(shouldRefresh(scrollOffset: 120), isTrue);
    });

    test('keeps the list after a short app switch', () {
      expect(
        shouldRefresh(backgroundDuration: const Duration(minutes: 9)),
        isFalse,
      );
    });

    test('keeps the list while artwork detail covers the route', () {
      expect(shouldRefresh(routeIsCurrent: false), isFalse);
    });

    test('keeps the list while another home tab is visible', () {
      expect(shouldRefresh(recommendedTabIsActive: false), isFalse);
    });

    test('keeps the list when the reader is deep in the feed', () {
      expect(shouldRefresh(scrollOffset: 121), isFalse);
    });
  });
}
