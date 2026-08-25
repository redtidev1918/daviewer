import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/updates/update_checker.dart';

const String _releasesUrl = 'https://github.com/redtidev1918/daviewer/releases';

/// A slim, dismissible banner shown above the Home feed when a newer release is
/// available. It never blocks content and never re-appears for a version the
/// user has dismissed.
final class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(updateCheckControllerProvider);
    if (!update.hasUpdate) return const SizedBox.shrink();
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);
    final version = update.latestVersion!;
    final color = theme.colorScheme.secondaryContainer;
    final onColor = theme.colorScheme.onSecondaryContainer;
    return Material(
      color: color,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4),
          child: Row(
            children: <Widget>[
              Icon(Icons.system_update_alt, size: 18, color: onColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.newVersionAvailable('v$version'),
                  style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(_releasesUrl),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(s.downloadUpdate),
              ),
              IconButton(
                tooltip: s.close,
                onPressed: () => ref
                    .read(updateCheckControllerProvider.notifier)
                    .dismiss(version),
                icon: const Icon(Icons.close, size: 18, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
