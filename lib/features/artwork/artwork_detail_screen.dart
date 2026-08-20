import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/runtime/runtime_provider.dart';
import 'artwork_detail_providers.dart';

final class ArtworkDetailScreen extends ConsumerStatefulWidget {
  const ArtworkDetailScreen({required this.artworkId, super.key});

  final String artworkId;

  @override
  ConsumerState<ArtworkDetailScreen> createState() =>
      _ArtworkDetailScreenState();
}

final class _ArtworkDetailScreenState
    extends ConsumerState<ArtworkDetailScreen> {
  StreamSubscription<TransferSnapshot>? _subscription;
  TransferSnapshot? _transfer;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _download(MediaAsset original) async {
    final manager = ref.read(runtimeProvider).transfers;
    final transferId = 'artwork-${widget.artworkId}-original';
    await manager.initialize();
    final snapshot = await manager.enqueue(
      TransferRequest(
        id: transferId,
        asset: original,
        filename: original.filename,
      ),
    );
    if (!mounted) return;
    setState(() => _transfer = snapshot);
    await _subscription?.cancel();
    _subscription = manager.updates
        .where((update) => update.id == transferId)
        .listen((update) {
          if (!mounted) return;
          setState(() => _transfer = update);
        });
  }

  Future<void> _pause() async {
    final transfer = _transfer;
    if (transfer == null) return;
    await ref.read(runtimeProvider).transfers.pause(transfer.id);
  }

  Future<void> _resume() async {
    final transfer = _transfer;
    if (transfer == null) return;
    await ref.read(runtimeProvider).transfers.resume(transfer.id);
  }

  Future<void> _cancel() async {
    final transfer = _transfer;
    if (transfer == null) return;
    await ref.read(runtimeProvider).transfers.cancel(transfer.id);
  }

  @override
  Widget build(BuildContext context) {
    final artwork = ref.watch(artworkDetailProvider(widget.artworkId));
    final original = ref.watch(originalFileProvider(widget.artworkId));
    final transfer = _transfer;

    return Scaffold(
      appBar: AppBar(
        title: Text(artwork.valueOrNull?.title ?? 'Artwork detail'),
      ),
      body: artwork.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (artwork) => original.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('$error')),
          data: (original) => ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              if (artwork.media.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: artwork.media.first.uri.toString(),
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const AspectRatio(
                    aspectRatio: 1,
                    child: ColoredBox(color: Color(0xffe9ecef)),
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.image),
                ),
              const SizedBox(height: 16),
              Text(
                artwork.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              TextButton(
                onPressed: () =>
                    context.go('/artist/${artwork.author.username}'),
                child: Text('by ${artwork.author.username}'),
              ),
              const SizedBox(height: 16),
              Text('Original: ${original.availability.name}'),
              if (original.mimeType != null) Text('MIME: ${original.mimeType}'),
              const SizedBox(height: 16),
              if (transfer == null)
                FilledButton(
                  onPressed: original.canTransfer
                      ? () => _download(original)
                      : null,
                  child: const Text('Download original'),
                )
              else
                _TransferControls(
                  transfer: transfer,
                  onPause: _pause,
                  onResume: _resume,
                  onCancel: _cancel,
                ),
              if (transfer?.localPath case final path?) ...[
                const SizedBox(height: 12),
                Text('Saved to $path'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _TransferControls extends StatelessWidget {
  const _TransferControls({
    required this.transfer,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final TransferSnapshot transfer;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: transfer.progress),
        const SizedBox(height: 8),
        Text('${(transfer.progress * 100).toStringAsFixed(0)}%'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: transfer.state == TransferState.running
                  ? onPause
                  : null,
              child: const Text('Pause'),
            ),
            OutlinedButton(
              onPressed: transfer.state == TransferState.paused
                  ? onResume
                  : null,
              child: const Text('Resume'),
            ),
            OutlinedButton(
              onPressed: transfer.state == TransferState.completed
                  ? null
                  : onCancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    );
  }
}
