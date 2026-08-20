import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/runtime/app_runtime.dart';
import 'core/runtime/runtime_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final runtime = AppRuntime.fromEnvironment();
  runApp(
    ProviderScope(
      overrides: <Override>[runtimeProvider.overrideWithValue(runtime)],
      child: const DAViewerApp(),
    ),
  );
}
