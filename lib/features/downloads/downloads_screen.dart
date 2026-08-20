import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import 'downloads_providers.dart';

final class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(downloadsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: records.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => AppErrorState(
          message: '$error',
          onRetry: () => ref.invalidate(downloadsProvider),
        ),
        data: (items) => items.isEmpty
            ? const AppEmptyState(message: 'No downloads yet.')
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
            if (snapshot.localPath != null) Text(snapshot.localPath!),
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
                  child: const Text('Pause'),
                ),
                OutlinedButton(
                  onPressed: snapshot.state == TransferState.paused
                      ? () async {
                          await manager.resume(snapshot.id);
                          onChanged();
                        }
                      : null,
                  child: const Text('Resume'),
                ),
                OutlinedButton(
                  onPressed: snapshot.isFinal
                      ? null
                      : () async {
                          await manager.cancel(snapshot.id);
                          onChanged();
                        },
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
