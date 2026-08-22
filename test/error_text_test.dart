import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/core/diagnostics/error_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strips the DAKitException code prefix', () {
    const error = DAKitException(
      kind: DAKitFailureKind.network,
      code: 'api.http.500',
      message: 'The official API request failed.',
    );
    expect(friendlyErrorMessage(error), 'The official API request failed.');
  });

  test('passes non-DAKit errors through unchanged', () {
    expect(friendlyErrorMessage('boom'), 'boom');
    expect(friendlyErrorMessage(StateError('nope')), contains('nope'));
  });
}
