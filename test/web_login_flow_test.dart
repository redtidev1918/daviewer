import 'package:daviewer/core/network/proxy_controller.dart';
import 'package:daviewer/features/web_login/web_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('login browser warning matches the actual proxy boundary', () {
    expect(systemBrowserFollowsSelectedProxy(ProxySource.system), isTrue);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.direct), isTrue);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.manual), isFalse);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.environment), isFalse);
    expect(systemBrowserFollowsSelectedProxy(ProxySource.dartDefine), isFalse);
  });

  test('provider security responses still prove the route is reachable', () {
    for (final status in <int>[200, 302, 403, 429, 503]) {
      expect(loginRouteReachedProvider(status), isTrue, reason: '$status');
    }
    expect(loginRouteReachedProvider(null), isFalse);
    expect(loginRouteReachedProvider(0), isFalse);
  });
}
