import 'package:daviewer/app/app.dart';
import 'package:daviewer/core/runtime/app_runtime.dart';
import 'package:daviewer/core/runtime/runtime_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows client id hint when unconfigured', (tester) async {
    final runtime = AppRuntime.fromEnvironment();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[runtimeProvider.overrideWithValue(runtime)],
        child: const DAViewerApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Pass DAKIT_CLIENT_ID at build time.'), findsOneWidget);
  });
}
