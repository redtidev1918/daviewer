import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_strings.dart';
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
          _MediaViewer(media: media, additionalMedia: additionalMedia),
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
          Text(
            s.bodyText,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Html(data: journalHtml),
          const SizedBox(height: 16),
        ] else if (!isJournal &&
            descriptionHtml != null &&
            descriptionHtml.trim().isNotEmpty) ...[
          Text(
            s.description,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Html(data: descriptionHtml),
          const SizedBox(height: 16),
        ] else if (description != null &&
            description.trim().isNotEmpty) ...[
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
          _DownloadSection(
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

/// Renders the artwork's media: static images, animated GIFs, videos, and
/// multi-image pages.
final class _MediaViewer extends StatefulWidget {
  const _MediaViewer({
    required this.media,
    this.additionalMedia = const <MediaAsset>[],
  });

  final List<MediaAsset> media;
  final List<MediaAsset> additionalMedia;

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

final class _MediaViewerState extends State<_MediaViewer> {
  int _page = 0;

  List<MediaAsset> get _pages => <MediaAsset>[
    ?_displayAsset(widget.media),
    ...widget.additionalMedia,
  ];

  static MediaAsset? _displayAsset(List<MediaAsset> media) {
    if (media.isEmpty) return null;
    final video = media.where((m) => m.kind == MediaKind.video).firstOrNull;
    if (video != null && video.uri != null) return video;
    final animation = media
        .where((m) => m.kind == MediaKind.animation)
        .firstOrNull;
    if (animation != null && animation.uri != null) return animation;
    // Inline display: prefer the largest resampled preview so we never force
    // the (potentially huge) original onto the image cache for inline use.
    return media
            .where(
              (m) => m.kind == MediaKind.image && m.role == MediaRole.preview,
            )
            .fold<MediaAsset?>(
              null,
              (best, m) =>
                  best == null || (m.width ?? 0) > (best.width ?? 0) ? m : best,
            ) ??
        media.where((m) => m.kind == MediaKind.image).firstOrNull;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: Color(0xffe9ecef),
          child: Icon(Icons.image, size: 48),
        ),
      );
    }

    if (pages.length == 1) {
      return _pageWidget(pages.first);
    }

    return Column(
      children: <Widget>[
        Stack(
          children: <Widget>[
            AspectRatio(
              aspectRatio: 1,
              child: PageView.builder(
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) => _pageWidget(pages[index]),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_page + 1} / ${pages.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            for (var i = 0; i < pages.length; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _page
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _pageWidget(MediaAsset asset) {
    final url = asset.uri?.toString();
    if (url == null) {
      return const ColoredBox(
        color: Color(0xffe9ecef),
        child: Icon(Icons.image, size: 48),
      );
    }
    if (asset.kind == MediaKind.video) {
      return _VideoPlayer(url: url);
    }
    // Animated GIFs render through Image.network so they actually animate.
    if (asset.mimeType == 'image/gif') {
      return _AnimatedImage(url: url);
    }
    return _TappableImage(url: url);
  }
}

final class _TappableImage extends StatelessWidget {
  const _TappableImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => _FullScreenImage(url: url),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.contain,
          width: double.infinity,
          placeholder: (context, url) => const AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: Color(0xffe9ecef),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          errorWidget: (context, url, error) => const AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: Color(0xffe9ecef),
              child: Icon(Icons.broken_image, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}

final class _AnimatedImage extends StatelessWidget {
  const _AnimatedImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        width: double.infinity,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const AspectRatio(
                aspectRatio: 1,
                child: ColoredBox(
                  color: Color(0xffe9ecef),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
        errorBuilder: (context, error, stack) => const AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: Color(0xffe9ecef),
            child: Icon(Icons.broken_image, size: 48),
          ),
        ),
      ),
    );
  }
}

final class _VideoPlayer extends StatefulWidget {
  const _VideoPlayer({required this.url});

  final String url;

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

final class _VideoPlayerState extends State<_VideoPlayer> {
  late final VideoPlayerController _controller;
  late final ChewieController _chewie;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {
          _chewie = ChewieController(
            videoPlayerController: _controller,
            autoPlay: false,
            looping: false,
            allowFullScreen: true,
            allowPlaybackSpeedChanging: false,
            materialProgressColors: ChewieProgressColors(
              playedColor: Colors.red,
              handleColor: Colors.red,
              bufferedColor: Colors.red.shade200,
            ),
          );
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _chewie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Chewie(controller: _chewie),
    );
  }
}

final class _DownloadSection extends StatelessWidget {
  const _DownloadSection({
    required this.s,
    required this.original,
    required this.downloadable,
    required this.transfer,
    required this.downloading,
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final AppStrings s;
  final MediaAsset original;
  final MediaAsset downloadable;
  final TransferSnapshot? transfer;
  final bool downloading;
  final VoidCallback onDownload;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (transfer != null) {
      return _TransferControls(
        s: s,
        transfer: transfer!,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
      );
    }

    final availability = original.availability;
    final canDownload = downloadable.canTransfer;
    final usingFallback = !original.canTransfer && downloadable.canTransfer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${s.originalStatusPrefix}${_availabilityLabel(availability)}'),
        if (original.mimeType != null) Text('MIME: ${original.mimeType}'),
        if (original.byteLength != null)
          Text('${s.sizeLabel}${_formatBytes(original.byteLength!)}'),
        if (usingFallback) ...[
          const SizedBox(height: 4),
          Text(
            s.fallbackDownloadNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canDownload && !downloading ? onDownload : null,
          icon: downloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(
            downloading
                ? s.downloading
                : usingFallback
                ? s.downloadImage
                : s.downloadOriginal,
          ),
        ),
        if (!canDownload) ...[
          const SizedBox(height: 8),
          Text(
            _availabilityHint(availability),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  String _availabilityLabel(MediaAvailability availability) {
    switch (availability) {
      case MediaAvailability.available:
        return s.availabilityAvailable;
      case MediaAvailability.loginRequired:
        return s.availabilityLoginRequired;
      case MediaAvailability.purchaseRequired:
        return s.availabilityPurchaseRequired;
      case MediaAvailability.restricted:
        return s.availabilityRestricted;
      case MediaAvailability.unavailable:
        return s.availabilityUnavailable;
      case MediaAvailability.missing:
        return s.availabilityMissing;
    }
  }

  String _availabilityHint(MediaAvailability availability) {
    switch (availability) {
      case MediaAvailability.loginRequired:
        return s.hintLoginRequired;
      case MediaAvailability.purchaseRequired:
        return s.hintPurchaseRequired;
      case MediaAvailability.restricted:
        return s.hintRestricted;
      case MediaAvailability.unavailable:
        return s.hintUnavailable;
      default:
        return '';
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

final class _TransferControls extends StatelessWidget {
  const _TransferControls({
    required this.s,
    required this.transfer,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final AppStrings s;
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
        if (transfer.localPath != null) ...[
          const SizedBox(height: 4),
          Text('${s.savedToPrefix}${transfer.localPath}'),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: <Widget>[
            OutlinedButton(
              onPressed: transfer.state == TransferState.running
                  ? onPause
                  : null,
              child: Text(s.pause),
            ),
            OutlinedButton(
              onPressed: transfer.state == TransferState.paused
                  ? onResume
                  : null,
              child: Text(s.resume),
            ),
            OutlinedButton(
              onPressed: transfer.state == TransferState.completed
                  ? null
                  : onCancel,
              child: Text(s.cancel),
            ),
          ],
        ),
      ],
    );
  }
}

final class _FullScreenImage extends ConsumerStatefulWidget {
  const _FullScreenImage({required this.url});

  final String url;

  @override
  ConsumerState<_FullScreenImage> createState() => _FullScreenImageState();
}

final class _FullScreenImageState extends ConsumerState<_FullScreenImage> {
  final TransformationController _transformation = TransformationController();
  bool _zoomed = false;

  @override
  void dispose() {
    _transformation.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transformation.value = Matrix4.identity();
      setState(() => _zoomed = false);
    } else {
      _transformation.value = Matrix4.identity()
        ..scaleByDouble(2.5, 2.5, 2.5, 1);
      setState(() => _zoomed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: <Widget>[
          IconButton(
            tooltip: _zoomed ? s.zoomReset : s.zoomIn,
            onPressed: _toggleZoom,
            icon: Icon(_zoomed ? Icons.zoom_out_map : Icons.zoom_in),
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _transformation,
          minScale: 0.5,
          maxScale: 8,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox.expand(
            child: CachedNetworkImage(
              imageUrl: widget.url,
              fit: BoxFit.contain,
              placeholder: (context, url) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorWidget: (context, url, error) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 48),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
