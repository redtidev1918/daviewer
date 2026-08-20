import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/runtime/app_runtime.dart';
import 'core/runtime/runtime_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = await AppRuntime.create();
  runApp(
    ProviderScope(
      overrides: <Override>[runtimeProvider.overrideWithValue(runtime)],
      child: const DAViewerApp(),
    ),
  );
}
