import 'package:daviewer/core/runtime/app_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release build ships a built-in public client id', () {
    final runtime = AppRuntime.fromEnvironment();
    // Ordinary users must not have to register their own OAuth app: the
    // release build has a public client id baked in.
    expect(runtime.isConfigured, isTrue);
    expect(runtime.clientId, isNotEmpty);
    expect(runtime.oauth, isNotNull);
    expect(runtime.transport, isNotNull);
  });
}
