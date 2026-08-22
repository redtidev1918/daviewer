import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import 'artwork_detail_providers.dart';
import 'download_section.dart';
import 'media_viewer.dart';

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
  bool _downloading = false;
  bool _favourite = false;
  bool _favBusy = false;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _toggleFavourite() async {
    if (_favBusy) return;
    setState(() => _favBusy = true);
    try {
      final runtime = ref.read(runtimeProvider);
      final social = OfficialSocialRepository(runtime.transport!);
      // Resolve the OAuth UUID: numeric web-feed ids map through
      // dadeviation/init before they can be favourited.
      final uuid = await ref.read(artworkUuidProvider(widget.artworkId).future);
      final result = _favourite
          ? await social.unfavourite(uuid)
          : await social.favourite(uuid);
      if (!mounted) return;
      setState(() => _favourite = result.isFavourite);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    final s = strings(ref.read(appLanguageProvider));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s.linkCopied)));
  }

  Future<void> _download(MediaAsset original) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
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
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
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
    final s = strings(ref.watch(appLanguageProvider));
    final artwork = ref.watch(artworkDetailProvider(widget.artworkId));
    final original = ref.watch(originalFileProvider(widget.artworkId));
    final description = ref.watch(artworkDescriptionProvider(widget.artworkId));
    final descriptionHtml = ref.watch(
      artworkDescriptionHtmlProvider(widget.artworkId),
    );
    final journalHtml = ref.watch(journalHtmlProvider(widget.artworkId));
    final additionalMedia = ref.watch(
      additionalMediaProvider(widget.artworkId),
    );
    final tags = ref.watch(artworkTagsProvider(widget.artworkId));
    final transfer = _transfer;

    // Reflect the real favourite state once it loads (the heart must show as
    // filled when re-opening an already-favourited artwork).
    ref.listen<AsyncValue<bool>>(favouriteStatusProvider(widget.artworkId), (
      previous,
      next,
    ) {
      final value = next.valueOrNull;
      if (value != null && mounted) {
        setState(() => _favourite = value);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(artwork.valueOrNull?.title ?? s.artworkDetail),
        actions: <Widget>[
          IconButton(
            tooltip: s.share,
            onPressed: () {
              final url = artwork.valueOrNull?.pageUri.toString();
              if (url != null) _copyLink(url);
            },
            icon: const Icon(Icons.share_outlined),
          ),
          IconButton(
            tooltip: _favourite ? s.unfavourite : s.favourite,
            onPressed: _toggleFavourite,
            icon: Icon(
              _favourite ? Icons.favorite : Icons.favorite_border,
              color: _favourite ? Colors.red : null,
            ),
          ),
        ],
      ),
      body: artwork.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (artwork) => original.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('$error')),
          data: (original) => _buildBody(
            artwork,
            original,
            transfer,
            description: description.valueOrNull,
            descriptionHtml: descriptionHtml.valueOrNull,
            journalHtml: journalHtml.valueOrNull,
            additionalMedia:
                additionalMedia.valueOrNull ?? const <MediaAsset>[],
            tags: tags.valueOrNull ?? const <String>[],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    Artwork artwork,
    MediaAsset original,
    TransferSnapshot? transfer, {
    String? description,
    String? descriptionHtml,
    String? journalHtml,
    List<MediaAsset> additionalMedia = const <MediaAsset>[],
    List<String> tags = const <String>[],
  }) {
    final s = strings(ref.read(appLanguageProvider));
    final media = artwork.media;
    // Journals/literature are rendered as text (with any embedded thumbs shown
    // above), never as an image with a bogus "original deleted" download row.
    final isJournal = artwork.pageUri.path.contains('/journal/');
    // When the original download is restricted (e.g. free limit reached),
    // fall back to the full-size image in the media list so the user can
    // still save it.
    final MediaAsset downloadable = original.canTransfer
        ? original
        : media.where((m) => m.kind == MediaKind.image).firstOrNull ?? original;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (media.isNotEmpty) ...[
          MediaViewer(media: media, additionalMedia: additionalMedia),
          const SizedBox(height: 16),
        ],
        Text(artwork.title, style: Theme.of(context).textTheme.headlineSmall),
        TextButton(
          onPressed: () => context.push('/artist/${artwork.author.username}'),
          child: Text('by ${artwork.author.username}'),
        ),
        const Divider(),
        if (isJournal &&
            journalHtml != null &&
            journalHtml.trim().isNotEmpty) ...[
          Text(s.bodyText, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Html(data: journalHtml),
          const SizedBox(height: 16),
        ] else if (!isJournal &&
            descriptionHtml != null &&
            descriptionHtml.trim().isNotEmpty) ...[
          Text(s.description, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Html(data: descriptionHtml),
          const SizedBox(height: 16),
        ] else if (description != null && description.trim().isNotEmpty) ...[
          Text(
            isJournal ? s.bodyText : s.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SelectableText(
            description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
        if (tags.isNotEmpty) ...[
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final tag in tags)
                ActionChip(
                  label: Text('#$tag'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      context.push('/tag/${Uri.encodeComponent(tag)}'),
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (!isJournal && media.isNotEmpty) ...[
          const SizedBox(height: 8),
          DownloadSection(
            s: s,
            original: original,
            downloadable: downloadable,
            transfer: transfer,
            downloading: _downloading,
            onDownload: () => _download(downloadable),
            onPause: _pause,
            onResume: _resume,
            onCancel: _cancel,
          ),
        ],
      ],
    );
  }
}
