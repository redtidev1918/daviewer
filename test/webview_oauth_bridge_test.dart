import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/auth/webview_oauth_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'external authorization is one-shot and bypasses WebView listeners',
    () async {
      final fallback = _RecordingLauncher();
      final bridge = WebViewOAuthBridge(fallback: fallback);
      final embedded = <Uri>[];
      final subscription = bridge.launchRequests.listen(embedded.add);
      final first = Uri.parse(
        'https://www.deviantart.com/oauth2/authorize?state=1',
      );
      final second = Uri.parse(
        'https://www.deviantart.com/oauth2/authorize?state=2',
      );

      bridge.launchNextExternally();
      await bridge.launch(first);
      await bridge.launch(second);
      await Future<void>.delayed(Duration.zero);

      expect(fallback.launched, <Uri>[first]);
      expect(embedded, <Uri>[second]);
      expect(bridge.canReopenExternalAuthorization, isTrue);
      await bridge.reopenExternalAuthorization();
      expect(fallback.launched, <Uri>[first, first]);
      bridge.finishExternalAuthorization();
      expect(bridge.canReopenExternalAuthorization, isFalse);
      await subscription.cancel();
      await bridge.dispose();
    },
  );

  test('cancelled external route does not leak into the next login', () async {
    final fallback = _RecordingLauncher();
    final bridge = WebViewOAuthBridge(fallback: fallback);
    final embedded = <Uri>[];
    final subscription = bridge.launchRequests.listen(embedded.add);
    final uri = Uri.parse('https://www.deviantart.com/oauth2/authorize');

    bridge.launchNextExternally();
    bridge.cancelExternalLaunch();
    await bridge.launch(uri);
    await Future<void>.delayed(Duration.zero);

    expect(fallback.launched, isEmpty);
    expect(embedded, <Uri>[uri]);
    await subscription.cancel();
    await bridge.dispose();
  });

  test('only the exact OAuth callback is accepted', () async {
    final bridge = WebViewOAuthBridge(fallback: _RecordingLauncher());
    final callbacks = <Uri>[];
    final subscription = bridge.callbacks.uris.listen(callbacks.add);
    final valid = Uri.parse('dakit://oauth/callback?code=ok&state=state');

    bridge
      ..addCallback(Uri.parse('https://example.com/callback'))
      ..addCallback(Uri.parse('dakit://other/callback'))
      ..addCallback(valid);
    await Future<void>.delayed(Duration.zero);

    expect(callbacks, <Uri>[valid]);
    await subscription.cancel();
    await bridge.dispose();
  });
}

final class _RecordingLauncher implements ExternalUriLauncher {
  final List<Uri> launched = <Uri>[];

  @override
  Future<void> launch(Uri uri) async {
    launched.add(uri);
  }
}
