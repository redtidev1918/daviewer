import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';

/// A shared settings entry shown in the AppBar of every top-level tab, so
/// users can reach settings from anywhere instead of only the home screen.
final class SettingsAction extends ConsumerWidget {
  const SettingsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    return IconButton(
      tooltip: s.settings,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.push('/settings'),
    );
  }
}
