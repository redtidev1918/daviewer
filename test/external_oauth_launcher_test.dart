import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/auth/external_oauth_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'every authorization uses the system launcher and can be reopened',
    () async {
      final delegate = _RecordingLauncher();
      final launcher = ExternalOAuthLauncher(delegate: delegate);
      final uri = Uri.parse(
        'https://www.deviantart.com/oauth2/authorize?state=one',
      );

      await launcher.launch(uri);
      expect(delegate.launched, <Uri>[uri]);
      expect(launcher.canReopen, isTrue);

      await launcher.reopen();
      expect(delegate.launched, <Uri>[uri, uri]);

      launcher.finish();
      expect(launcher.canReopen, isFalse);
    },
  );

  test('a launch failure cannot leave a stale transaction to reopen', () async {
    final launcher = ExternalOAuthLauncher(delegate: _FailingLauncher());

    await expectLater(
      launcher.launch(Uri.parse('https://example.test/authorize')),
      throwsStateError,
    );
    expect(launcher.canReopen, isFalse);
  });
}

final class _RecordingLauncher implements ExternalUriLauncher {
  final List<Uri> launched = <Uri>[];

  @override
  Future<void> launch(Uri uri) async => launched.add(uri);
}

final class _FailingLauncher implements ExternalUriLauncher {
  @override
  Future<void> launch(Uri uri) async => throw StateError('cannot open');
}
