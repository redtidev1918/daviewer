import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/diagnostics/app_logger.dart';
import 'core/runtime/app_runtime.dart';
import 'core/runtime/runtime_provider.dart';

String _globalProxyDirective = 'DIRECT';

final class _AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.findProxy = (uri) => _globalProxyDirective;
    return client;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logger = await AppLogger.initialize();
  installGlobalErrorHandlers(logger);
  logger.info('app', 'DAViewer starting');

  final runtime = await AppRuntime.create();
  _globalProxyDirective = runtime.proxyController?.directive ?? 'DIRECT';
  runtime.proxyController?.addListener(() {
    _globalProxyDirective = runtime.proxyController!.directive;
  });
  HttpOverrides.global = _AppHttpOverrides();
  runApp(
    ProviderScope(
      overrides: <Override>[runtimeProvider.overrideWithValue(runtime)],
      child: const DAViewerApp(),
    ),
  );
}
