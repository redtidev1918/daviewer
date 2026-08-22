import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/skeleton.dart';
import 'artwork_detail_providers.dart';
import 'artwork_detail_sections.dart';
import 'collection_sections.dart';
import 'download_section.dart';
import 'favourite_actions.dart';
import 'media_viewer.dart';
import 'more_like_this.dart';

final class ArtworkDetailScreen extends ConsumerStatefulWidget {
  const ArtworkDetailScreen({required this.artworkId, super.key});

  final String artworkId;

  @override
  ConsumerState<ArtworkDetailScreen> createState() =>
      _ArtworkDetailScreenState();
}

final class _ArtworkDetailScreenState extends ConsumerState<ArtworkDetailScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<TransferSnapshot>? _subscription;
  TransferSnapshot? _transfer;
  bool _downloading = false;
  bool _favourite = false;
  bool _favBusy = false;

  late final AnimationController _heartController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final Animation<double> _heartScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.4,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.4,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInBack)),
      weight: 50,
    ),
  ]).animate(_heartController);

  @override
  void dispose() {
    _heartController.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _toggleFavourite() async {
    if (_favBusy) return;
    setState(() => _favBusy = true);
    try {
      final isFavourite = await setArtworkFavourite(
        ref,
        widget.artworkId,
        !_favourite,
      );
      if (!mounted) return;
      setState(() => _favourite = isFavourite);
      _heartController.forward(from: 0);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
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

  void _openLink(String? url) {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
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
            icon: ScaleTransition(
              scale: _heartScale,
              child: Icon(
                _favourite ? Icons.favorite : Icons.favorite_border,
                color: _favourite ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: artwork.when(
          loading: () => const SkeletonDetail(key: ValueKey('skeleton-art')),
          error: (error, stackTrace) => AppErrorState(
            key: const ValueKey('error-art'),
            message: friendlyErrorMessage(error),
            onRetry: () =>
                ref.invalidate(artworkDetailProvider(widget.artworkId)),
          ),
          data: (artwork) => original.when(
            loading: () => const SkeletonDetail(key: ValueKey('skeleton-orig')),
            error: (error, stackTrace) => AppErrorState(
              key: const ValueKey('error-orig'),
              message: friendlyErrorMessage(error),
            ),
            data: (original) => KeyedSubtree(
              key: const ValueKey('content'),
              child: _buildBody(
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
    // fall back to a *downloadable* image in the media list so the user can
    // still save it — never a gated (premium/restricted) one.
    final MediaAsset downloadable = original.canTransfer
        ? original
        : media
                  .where((m) => m.kind == MediaKind.image && m.canTransfer)
                  .firstOrNull ??
              original;

    // The detail screen is a thin composition of self-contained sections. To
    // add another related-content block (e.g. Suggested Deviants / Collections),
    // drop a new widget below; each section owns its provider, its loading /
    // error / empty handling, and hides itself when it has nothing to show.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (media.isNotEmpty) ...[
          MediaViewer(
            media: media,
            additionalMedia: additionalMedia,
            heroTag: 'artwork-${artwork.id}',
          ),
          const SizedBox(height: 16),
        ],
        ArtworkHeader(artwork: artwork, s: s),
        const Divider(),
        ArtworkDescriptionSection(
          isJournal: isJournal,
          s: s,
          journalHtml: journalHtml,
          descriptionHtml: descriptionHtml,
          description: description,
          onOpenLink: _openLink,
        ),
        if (tags.isNotEmpty) ArtworkTagsSection(tags: tags),
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
        const Divider(),
        MoreLikeThisSection(artworkId: widget.artworkId),
        FeaturedInCollectionsSection(artworkId: widget.artworkId),
        SuggestedCollectionsSection(artworkId: widget.artworkId),
      ],
    );
  }
}
