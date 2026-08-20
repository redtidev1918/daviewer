import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import 'downloads_providers.dart';

final class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(downloadsProvider);
    final s = strings(ref.watch(appLanguageProvider));
    return Scaffold(
      appBar: AppBar(title: Text(s.downloads)),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(downloadsProvider),
        ),
        data: (items) => items.isEmpty
            ? AppEmptyState(message: s.noDownloads)
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final snapshot = items[index];
                  return _DownloadTile(
                    snapshot: snapshot,
                    onChanged: () => ref.invalidate(downloadsProvider),
                  );
                },
              ),
      ),
    );
  }
}

final class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.snapshot, required this.onChanged});

  final TransferSnapshot snapshot;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(runtimeProvider).transfers;
    final language = ref.watch(appLanguageProvider);
    final s = strings(language);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              snapshot.filename ?? snapshot.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(snapshot.state.name),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: snapshot.progress),
            const SizedBox(height: 8),
            if (snapshot.localPath != null) ...[
              const SizedBox(height: 8),
              Text(
                snapshot.localPath!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: Text(language == AppLanguage.zh ? '打开文件' : 'Open'),
                    onPressed: () => _openFile(snapshot.localPath!),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: Text(
                      language == AppLanguage.zh ? '打开文件夹' : 'Folder',
                    ),
                    onPressed: () => _openFolder(snapshot.localPath!),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: snapshot.state == TransferState.running
                      ? () async {
                          await manager.pause(snapshot.id);
                          onChanged();
                        }
                      : null,
                  child: Text(s.pause),
                ),
                OutlinedButton(
                  onPressed: snapshot.state == TransferState.paused
                      ? () async {
                          await manager.resume(snapshot.id);
                          onChanged();
                        }
                      : null,
                  child: Text(s.resume),
                ),
                OutlinedButton(
                  onPressed: snapshot.isFinal
                      ? null
                      : () async {
                          await manager.cancel(snapshot.id);
                          onChanged();
                        },
                  child: Text(s.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _openFile(String path) async {
    final uri = Uri.file(path);
    if (!await launchUrl(uri)) {
      throw Exception('Could not open $path');
    }
  }

  static Future<void> _openFolder(String filePath) async {
    final dir = File(filePath).parent.path;
    final uri = Uri.directory(dir);
    if (!await launchUrl(uri)) {
      throw Exception('Could not open folder $dir');
    }
  }
}
