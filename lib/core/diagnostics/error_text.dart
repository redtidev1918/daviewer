import 'package:dakit_flutter/dakit_flutter.dart';

import '../l10n/app_strings.dart';

/// A human-readable error message for display, without the
/// `DAKitException(code):` prefix that [DAKitException.toString] adds.
String friendlyErrorMessage(Object error) {
  if (error is DAKitException) return error.message;
  return '$error';
}

/// Authentication failures need product-language recovery, not SDK or
/// Keychain implementation text such as "Unable to access".
String friendlyLoginErrorMessage(Object error, AppStrings strings) {
  if (error is! DAKitException) return strings.loginUnexpectedFailure;
  if (error.code.startsWith('pending_authorization_store.')) {
    return strings.loginRecoveryStorageUnavailable;
  }
  if (error.code.startsWith('token_store.')) {
    return strings.loginSessionStorageUnavailable;
  }
  if (error.code == 'oauth.callback.timeout') {
    return strings.loginCallbackTimeout;
  }
  if (error.code.startsWith('oauth.browser.')) {
    return strings.loginBrowserOpenFailed;
  }
  if (error.kind == DAKitFailureKind.network || error.retryable) {
    return strings.loginNetworkFailure;
  }
  return strings.loginUnexpectedFailure;
}
