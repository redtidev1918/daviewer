import 'package:daviewer/core/auth/web_session_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partial background page cannot overwrite a signed-in snapshot', () {
    expect(
      shouldCommitBackgroundWebSession(csrf: 'csrf', username: ''),
      isFalse,
    );
    expect(
      shouldCommitBackgroundWebSession(csrf: '', username: 'user'),
      isFalse,
    );
  });

  test('identified background session can rotate the CSRF', () {
    expect(
      shouldCommitBackgroundWebSession(csrf: 'csrf', username: 'user'),
      isTrue,
    );
  });
}
