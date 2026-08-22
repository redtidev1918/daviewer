import 'package:dakit_flutter/dakit_flutter.dart';

/// A human-readable error message for display, without the
/// `DAKitException(code):` prefix that [DAKitException.toString] adds.
String friendlyErrorMessage(Object error) {
  if (error is DAKitException) return error.message;
  return '$error';
}
