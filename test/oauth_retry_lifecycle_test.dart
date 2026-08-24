import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cancelled authorization can immediately create a fresh transaction',
    () async {
      final callbacks = _CallbackSource();
      addTearDown(callbacks.close);
      final launcher = _RecordingLauncher();
      final pendingStore = _MemoryPendingStore();
      final client = DAKitOAuthClient(
        config: OAuthConfig(
          clientId: 'test-client',
          redirectUri: Uri.parse('dakit://oauth/callback'),
        ),
        tokenStore: _MemoryTokenStore(),
        pendingStore: pendingStore,
        launcher: launcher,
        callbacks: callbacks,
        endpoint: _UnusedEndpoint(),
      );

      final first = client.authorize();
      final firstFailure = expectLater(
        first,
        throwsA(
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'oauth.transaction.cancelled',
          ),
        ),
      );
      await _waitForLaunches(launcher, 1);
      final firstState = launcher.uris.single.queryParameters['state'];
      expect(client.isAuthorizing, isTrue);
      expect(pendingStore.value, isNotNull);

      await client.authorization.cancelPending();
      await firstFailure;
      expect(client.isAuthorizing, isFalse);
      expect(pendingStore.value, isNull);

      final second = client.authorize();
      final secondFailure = expectLater(
        second,
        throwsA(
          isA<DAKitException>().having(
            (error) => error.code,
            'code',
            'oauth.transaction.cancelled',
          ),
        ),
      );
      await _waitForLaunches(launcher, 2);
      final secondState = launcher.uris.last.queryParameters['state'];
      expect(secondState, isNot(firstState));

      await client.authorization.cancelPending();
      await secondFailure;
    },
  );
}

Future<void> _waitForLaunches(_RecordingLauncher launcher, int count) async {
  for (
    var attempt = 0;
    attempt < 20 && launcher.uris.length < count;
    attempt++
  ) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(launcher.uris, hasLength(count));
}

final class _RecordingLauncher implements ExternalUriLauncher {
  final List<Uri> uris = <Uri>[];

  @override
  Future<void> launch(Uri uri) async => uris.add(uri);
}

final class _CallbackSource implements CallbackUriSource {
  final StreamController<Uri> _controller = StreamController<Uri>.broadcast();

  @override
  Stream<Uri> get uris => _controller.stream;

  Future<void> close() => _controller.close();
}

final class _MemoryPendingStore implements PendingAuthorizationStore {
  PendingAuthorization? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<PendingAuthorization?> read() async => value;

  @override
  Future<void> write(PendingAuthorization pending) async => value = pending;
}

final class _MemoryTokenStore implements TokenStore {
  AuthTokens? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async => value = tokens;
}

final class _UnusedEndpoint implements OAuthEndpoint {
  @override
  Future<Map<String, Object?>> postForm(
    Uri endpoint,
    Map<String, String> form,
  ) => throw StateError('No token exchange is expected in this test.');
}
