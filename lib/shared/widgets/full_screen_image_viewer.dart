import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/diagnostics/app_logger.dart';

/// The single full-screen image experience used by remote artwork media and
/// local downloads. It owns all zoom limits, double-tap behavior and controls
/// so the two entry points cannot drift apart again.
final class FullScreenImageViewer extends ConsumerStatefulWidget {
  const FullScreenImageViewer({
    required this.imageProvider,
    this.heroTag,
    this.onPreviousArtwork,
    this.onNextArtwork,
    super.key,
  });

  final ImageProvider<Object> imageProvider;
  final Object? heroTag;
  final VoidCallback? onPreviousArtwork;
  final VoidCallback? onNextArtwork;

  @override
  ConsumerState<FullScreenImageViewer> createState() =>
      _FullScreenImageViewerState();
}

final class _FullScreenImageViewerState
    extends ConsumerState<FullScreenImageViewer> {
  final TransformationController _transformation = TransformationController();
  TapDownDetails? _doubleTap;
  bool _zoomed = false;
  double _horizontalDrag = 0;

  @override
  void initState() {
    super.initState();
    _transformation.addListener(_syncZoomState);
  }

  @override
  void dispose() {
    _transformation
      ..removeListener(_syncZoomState)
      ..dispose();
    super.dispose();
  }

  void _syncZoomState() {
    final zoomed = _transformation.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed && mounted) setState(() => _zoomed = zoomed);
  }

  void _toggleZoom() {
    if (_zoomed) {
      _transformation.value = Matrix4.identity();
      return;
    }
    final position = _doubleTap?.localPosition;
    const scale = 2.5;
    final matrix = Matrix4.identity();
    if (position != null) {
      matrix.translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      );
    }
    matrix.scaleByDouble(scale, scale, 1, 1);
    _transformation.value = matrix;
  }

  void _finishHorizontalDrag(DragEndDetails details) {
    AppLogger.instance.debug(
      'fullscreen-swipe',
      'drag end, zoomed=$_zoomed, drag=$_horizontalDrag, '
          'velocity=${details.primaryVelocity}, '
          'hasPrev=${widget.onPreviousArtwork != null}, '
          'hasNext=${widget.onNextArtwork != null}',
    );
    if (_zoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    final threshold = (MediaQuery.sizeOf(context).width * 0.16).clamp(
      56.0,
      96.0,
    );
    final callback = switch ((_horizontalDrag, velocity)) {
      (final distance, _) when distance > threshold => widget.onPreviousArtwork,
      (_, final speed) when speed > 700 => widget.onPreviousArtwork,
      (final distance, _) when distance < -threshold => widget.onNextArtwork,
      (_, final speed) when speed < -700 => widget.onNextArtwork,
      _ => null,
    };
    _horizontalDrag = 0;
    if (callback == null) return;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final canSwipeArtwork =
        !_zoomed &&
        (widget.onPreviousArtwork != null || widget.onNextArtwork != null);
    Widget image = Image(
      image: widget.imageProvider,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, synchronouslyLoaded) {
        if (synchronouslyLoaded || frame != null) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stackTrace) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.broken_image, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            Text(
              s.imageLoadFailed,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
    final heroTag = widget.heroTag;
    if (heroTag != null) image = Hero(tag: heroTag, child: image);

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
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (details) => _doubleTap = details,
        onDoubleTap: _toggleZoom,
        onHorizontalDragStart: canSwipeArtwork
            ? (_) {
                AppLogger.instance.debug(
                  'fullscreen-swipe',
                  'drag start (onPrev=${widget.onPreviousArtwork != null}, onNext=${widget.onNextArtwork != null})',
                );
                _horizontalDrag = 0;
              }
            : null,
        onHorizontalDragUpdate: canSwipeArtwork
            ? (details) => _horizontalDrag += details.delta.dx
            : null,
        onHorizontalDragCancel: canSwipeArtwork
            ? () => _horizontalDrag = 0
            : null,
        onHorizontalDragEnd: canSwipeArtwork ? _finishHorizontalDrag : null,
        // 未缩放时不挂 InteractiveViewer：它的手势识别器即使在
        // panEnabled=false 时也会参与竞技场并抢走水平拖动，
        // 导致全屏查看器里的左右滑动切换作品永远不触发。
        // 缩放后仍需要 InteractiveViewer 来支持平移与边界控制。
        child: _zoomed
            ? InteractiveViewer(
                transformationController: _transformation,
                minScale: 1,
                maxScale: 8,
                boundaryMargin: const EdgeInsets.all(80),
                panEnabled: true,
                child: SizedBox.expand(child: image),
              )
            : Center(child: image),
      ),
    );
  }
}
