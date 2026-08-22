import 'dart:async';
import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/settings_action.dart';
import 'download_helpers.dart';
import 'downloads_providers.dart';

final class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(downloadsProvider);
    final s = strings(ref.watch(appLanguageProvider));
    return Scaffold(
      appBar: AppBar(
        title: Text(s.downloads),
        actions: const <Widget>[SettingsAction()],
      ),
      body: _buildBody(context, ref, state, s),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    DownloadsState state,
    AppStrings s,
  ) {
    if (state.error != null && state.items.isEmpty) {
      return AppErrorState(
        message: '${state.error}',
        onRetry: () => ref.read(downloadsProvider.notifier).refresh(),
      );
    }
    if (state.items.isEmpty && state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              width: constraints.maxWidth,
              child: AppEmptyState(message: s.noDownloads),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(downloadsProvider.notifier).refresh(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: state.items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final snapshot = state.items[index];
          return _DownloadTile(snapshot: snapshot);
        },
      ),
    );
  }
}

final class _DownloadTile extends ConsumerWidget {
  const _DownloadTile({required this.snapshot});

  final TransferSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(runtimeProvider).transfers;
    final s = strings(ref.watch(appLanguageProvider));
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  _iconForState(snapshot.state),
                  size: 20,
                  color: _colorForState(snapshot.state, scheme),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    snapshot.filename ?? snapshot.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _labelForState(snapshot.state, s),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: _colorForState(snapshot.state, scheme)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: snapshot.progress,
              borderRadius: BorderRadius.circular(4),
            ),
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
                    label: Text(s.open),
                    onPressed: () => _openImage(context, snapshot.localPath!),
                  ),
                  if (artworkIdFromTransfer(snapshot.id) case final id?)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.art_track, size: 18),
                      label: Text(s.viewDetail),
                      onPressed: () => context.push('/artwork/$id'),
                    ),
                ],
              ),
            ],
            if (!snapshot.isFinal) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: snapshot.state == TransferState.running
                        ? () => manager.pause(snapshot.id)
                        : null,
                    child: Text(s.pause),
                  ),
                  OutlinedButton(
                    onPressed: snapshot.state == TransferState.paused
                        ? () => manager.resume(snapshot.id)
                        : null,
                    child: Text(s.resume),
                  ),
                  OutlinedButton(
                    onPressed: () => manager.cancel(snapshot.id),
                    child: Text(s.cancel),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static IconData _iconForState(TransferState state) => switch (state) {
    TransferState.completed => Icons.check_circle,
    TransferState.running => Icons.downloading,
    TransferState.paused => Icons.pause_circle,
    TransferState.failed => Icons.error,
    TransferState.cancelled => Icons.cancel,
    _ => Icons.schedule,
  };

  static Color _colorForState(TransferState state, ColorScheme scheme) =>
      switch (state) {
        TransferState.completed => Colors.green,
        TransferState.failed => scheme.error,
        TransferState.cancelled => scheme.outline,
        TransferState.running => scheme.primary,
        _ => scheme.outline,
      };

  static String _labelForState(TransferState state, AppStrings s) {
    return switch (state) {
      TransferState.completed => s.transferDone,
      TransferState.running => s.transferDownloading,
      TransferState.paused => s.transferPaused,
      TransferState.failed => s.transferFailed,
      TransferState.cancelled => s.transferCancelled,
      _ => s.transferQueued,
    };
  }

  void _openImage(BuildContext context, String path) {
    if (isImageFile(path)) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => _LocalImageViewer(path: path)),
      );
    } else {
      // Videos and other files open with the platform's default handler.
      unawaited(launchUrl(Uri.file(path)));
    }
  }
}

/// A simple full-screen viewer for a locally downloaded image.
final class _LocalImageViewer extends StatelessWidget {
  const _LocalImageViewer({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 8,
          child: Image.file(File(path), fit: BoxFit.contain),
        ),
      ),
    );
  }
}
