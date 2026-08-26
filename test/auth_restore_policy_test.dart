import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'cold-start timeout does not force a persisted user to sign in again',
    () {
      expect(
        shouldPreserveSessionAfterRestoreFailure(TimeoutException('slow')),
        isTrue,
      );
    },
  );

  test('network, upstream and Keychain failures preserve the session', () {
    for (final kind in <DAKitFailureKind>[
      DAKitFailureKind.network,
      DAKitFailureKind.upstream,
      DAKitFailureKind.rateLimit,
      DAKitFailureKind.storage,
    ]) {
      expect(
        shouldPreserveSessionAfterRestoreFailure(
          DAKitException(kind: kind, code: 'temporary', message: 'temporary'),
        ),
        isTrue,
      );
    }
  });

  test('only missing or revoked credentials require authorization', () {
    expect(
      shouldPreserveSessionAfterRestoreFailure(
        const DAKitException(
          kind: DAKitFailureKind.authentication,
          code: 'oauth.session.missing',
          message: 'missing',
        ),
      ),
      isFalse,
    );
    expect(
      shouldPreserveSessionAfterRestoreFailure(
        const DAKitException(
          kind: DAKitFailureKind.authentication,
          code: 'oauth.error.invalid_grant',
          message: 'revoked',
        ),
      ),
      isFalse,
    );
    expect(
      shouldPreserveSessionAfterRestoreFailure(
        const DAKitException(
          kind: DAKitFailureKind.authentication,
          code: 'oauth.refresh.invalid',
          message: 'refresh token invalid',
        ),
      ),
      isFalse,
    );
  });

  test('legacy DeviantArt invalid_request refresh response is definitive', () {
    expect(
      shouldPreserveSessionAfterRestoreFailure(
        const DAKitException(
          kind: DAKitFailureKind.authentication,
          code: 'oauth.provider.invalid_request',
          message: 'The refresh_token is invalid.',
          details: <String, Object?>{
            'provider_description': 'The refresh_token is invalid.',
          },
        ),
      ),
      isFalse,
    );
    expect(
      shouldPreserveSessionAfterRestoreFailure(
        const DAKitException(
          kind: DAKitFailureKind.authentication,
          code: 'oauth.provider.invalid_request',
          message: 'The authorization code is invalid.',
        ),
      ),
      isTrue,
    );
  });

  test('a transient restore failure always preserves the session', () {
    // validTokens already verified a stored token, so a network/timeout error
    // while refreshing must never surface as signed-out.
    expect(
      shouldPreserveSessionAfterRestoreFailure(TimeoutException('offline')),
      isTrue,
    );
    expect(
      shouldPreserveSessionAfterRestoreFailure(
        DAKitException(
          kind: DAKitFailureKind.network,
          code: 'network.connection',
          message: 'offline',
        ),
      ),
      isTrue,
    );
  });
}
