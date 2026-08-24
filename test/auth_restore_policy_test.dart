import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/auth/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cold-start timeout does not force a persisted user to sign in again', () {
    expect(
      shouldPreserveSessionAfterRestoreFailure(TimeoutException('slow')),
      isTrue,
    );
  });

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
  });
}
