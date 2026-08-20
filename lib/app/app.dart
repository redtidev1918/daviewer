import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/app_strings.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final class DAViewerApp extends ConsumerWidget {
  const DAViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final language = ref.watch(appLanguageProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: language == AppLanguage.zh ? const Locale('zh') : const Locale('en'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
