import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';

/// Picks the single asset to display inline from an artwork's [media]:
/// a playable video first, then an animation, then the largest resampled
/// preview image (so the potentially huge original is never forced onto the
/// inline cache), falling back to any image. Gated assets (premium/paid,
/// blocked) are skipped when an accessible alternative exists, so paid content
/// still renders its accessible thumbnail instead of a broken image.
MediaAsset? selectDisplayAsset(List<MediaAsset> media) {
  if (media.isEmpty) return null;
  bool available(MediaAsset m) => m.availability == MediaAvailability.available;
  final video = media
      .where((m) => m.kind == MediaKind.video && available(m))
      .firstOrNull;
  if (video != null && video.uri != null) return video;
  final animation = media
      .where((m) => m.kind == MediaKind.animation && available(m))
      .firstOrNull;
  if (animation != null && animation.uri != null) return animation;
  final accessibleImage = media
      .where(
        (m) =>
            m.kind == MediaKind.image &&
            m.role == MediaRole.preview &&
            available(m),
      )
      .fold<MediaAsset?>(
        null,
        (best, m) =>
            best == null || (m.width ?? 0) > (best.width ?? 0) ? m : best,
      );
  if (accessibleImage != null) return accessibleImage;
  return media.where((m) => m.kind == MediaKind.image).firstOrNull;
}

/// Renders an artwork's media: static images, animated GIFs, videos, and
/// multi-image pages (with a page counter and dot indicators).
final class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.media,
    this.additionalMedia = const <MediaAsset>[],
    this.heroTag,
  });

  final List<MediaAsset> media;
  final List<MediaAsset> additionalMedia;

  /// Hero tag for the first page's image, used to animate the grid → detail
  /// transition (matching [ArtworkCard]'s tag).
  final String? heroTag;

  @override
  State<MediaViewer> createState() => MediaViewerState();
}

final class MediaViewerState extends State<MediaViewer> {
  int _page = 0;

  List<MediaAsset> get _pages => <MediaAsset>[
    ?selectDisplayAsset(widget.media),
    ...widget.additionalMedia,
  ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    if (pages.isEmpty) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ColoredBox(
          color: AppTheme.placeholderColor,
          child: Icon(Icons.image, size: 48),
        ),
      );
    }

    if (pages.length == 1) {
      return _pageWidget(pages.first, heroTag: widget.heroTag);
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
                itemBuilder: (context, index) => _pageWidget(
                  pages[index],
                  heroTag: index == 0 ? widget.heroTag : null,
                ),
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

  Widget _pageWidget(MediaAsset asset, {String? heroTag}) {
    // Gated content (premium/paid, blocked, deleted): show a clear placeholder
    // instead of trying to load a URL that will 403 and render a broken image.
    if (asset.availability != MediaAvailability.available) {
      return _GatedPlaceholder(availability: asset.availability);
    }
    final url = asset.uri?.toString();
    if (url == null) {
      return const ColoredBox(
        color: AppTheme.placeholderColor,
        child: Icon(Icons.image, size: 48),
      );
    }
    final Widget child;
    if (asset.kind == MediaKind.video) {
      child = _VideoPlayer(url: url);
    } else if (asset.mimeType == 'image/gif') {
      // Animated GIFs render through Image.network so they actually animate.
      child = _AnimatedImage(url: url);
    } else {
      child = _TappableImage(url: url);
    }
    if (heroTag != null && asset.kind != MediaKind.video) {
      return Hero(tag: heroTag, child: child);
    }
    return child;
  }
}

/// A placeholder for content the user cannot access (premium/paid, blocked, or
/// deleted), showing the reason instead of a broken image.
final class _GatedPlaceholder extends StatelessWidget {
  const _GatedPlaceholder({required this.availability});

  final MediaAvailability availability;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = strings(
      ProviderScope.containerOf(
        context,
        listen: false,
      ).read(appLanguageProvider),
    );
    final label = switch (availability) {
      MediaAvailability.purchaseRequired => s.availabilityPurchaseRequired,
      MediaAvailability.restricted => s.availabilityRestricted,
      MediaAvailability.unavailable => s.availabilityUnavailable,
      MediaAvailability.loginRequired => s.availabilityLoginRequired,
      MediaAvailability.missing => s.availabilityMissing,
      MediaAvailability.available => '',
    };
    final icon = switch (availability) {
      MediaAvailability.purchaseRequired => Icons.lock_outline,
      MediaAvailability.restricted => Icons.visibility_off_outlined,
      MediaAvailability.missing => Icons.delete_outline,
      _ => Icons.block,
    };
    return AspectRatio(
      aspectRatio: 1,
      child: ColoredBox(
        color: AppTheme.placeholderColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 48, color: scheme.onSurfaceVariant),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
          memCacheWidth: 1080,
          // Progressive loading: show a tiny (blurred) version of the same
          // image instantly, then cross-fade to the full-resolution decode.
          placeholder: (context, url) => AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: url,
              memCacheWidth: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) =>
                  const ColoredBox(color: AppTheme.placeholderColor),
              errorWidget: (context, url, error) =>
                  const ColoredBox(color: AppTheme.placeholderColor),
            ),
          ),
          errorWidget: (context, url, error) => const AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: AppTheme.placeholderColor,
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
                  color: AppTheme.placeholderColor,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
        errorBuilder: (context, error, stack) => const AspectRatio(
          aspectRatio: 1,
          child: ColoredBox(
            color: AppTheme.placeholderColor,
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
              // Progressive loading: blurred tiny version first, then the
              // full-resolution decode cross-fades in.
              placeholder: (context, url) => CachedNetworkImage(
                imageUrl: url,
                memCacheWidth: 40,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
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
