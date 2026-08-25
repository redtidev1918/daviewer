import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/diagnostics/error_text.dart';
import 'package:daviewer/core/l10n/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pending storage errors never expose implementation text', () {
    const error = DAKitException(
      kind: DAKitFailureKind.storage,
      code: 'pending_authorization_store.clear_failed',
      message: 'Unable to access the pending OAuth transaction securely.',
    );

    final message = friendlyLoginErrorMessage(error, AppStrings.zh);

    expect(message, contains('保持 DAViewer 开启'));
    expect(message, isNot(contains('Unable to access')));
  });

  test('token storage errors are distinguished from network failures', () {
    const error = DAKitException(
      kind: DAKitFailureKind.storage,
      code: 'token_store.write_failed',
      message: 'Unable to persist the OAuth session securely.',
    );

    final message = friendlyLoginErrorMessage(error, AppStrings.zh);

    expect(message, contains('不是账号或网络错误'));
  });

  test('unknown SDK details stay in diagnostics', () {
    const error = DAKitException(
      kind: DAKitFailureKind.parsing,
      code: 'oauth.unexpected',
      message: 'Internal provider detail that must not reach users',
    );

    final message = friendlyLoginErrorMessage(error, AppStrings.zh);

    expect(message, contains('重新尝试'));
    expect(message, isNot(contains('Internal provider detail')));
  });
}
