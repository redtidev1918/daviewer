import 'package:flutter/material.dart';

/// A shimmer placeholder block for skeleton loading — the modern replacement
/// for a bare spinner. Renders a rounded block with a light gradient sweep.
final class Skeleton extends StatefulWidget {
  const Skeleton({this.width, this.height, this.radius = 8, super.key});

  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

final class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = scheme.surfaceContainerLowest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: const Alignment(-1.5, 0),
            end: const Alignment(1.5, 0),
            colors: <Color>[base, highlight, base],
            stops: const <double>[0.35, 0.5, 0.65],
            transform: _SlidingGradientTransform(_controller.value),
          ),
        ),
      ),
    );
  }
}

final class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (percent * 2 - 1), 0, 0);
  }
}

/// A grid of shimmer cards matching [ArtworkFeedGrid]'s layout, shown while a
/// feed is loading.
final class SkeletonGrid extends StatelessWidget {
  const SkeletonGrid({this.itemCount = 12, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => const _SkeletonCard(),
    );
  }
}

final class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    // Matches the full-bleed artwork card (image with overlaid caption).
    return const Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Skeleton(radius: 12),
        Positioned(
          left: 10,
          right: 10,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Skeleton(width: double.infinity, height: 13, radius: 4),
              SizedBox(height: 6),
              Skeleton(width: 72, height: 11, radius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

/// A skeleton for the artwork detail screen (image + title + body lines).
final class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        AspectRatio(aspectRatio: 1, child: Skeleton(radius: 12)),
        SizedBox(height: 16),
        Skeleton(width: 220, height: 22),
        SizedBox(height: 12),
        Skeleton(width: 120, height: 14, radius: 6),
        SizedBox(height: 20),
        Skeleton(width: double.infinity, height: 14, radius: 6),
        SizedBox(height: 8),
        Skeleton(width: double.infinity, height: 14, radius: 6),
        SizedBox(height: 8),
        Skeleton(width: 160, height: 14, radius: 6),
      ],
    );
  }
}

/// A list of shimmer rows (avatar + title + subtitle), used while list-style
/// screens (notifications, downloads, watching, …) load.
final class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 8, super.key});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) => const _SkeletonListTile(),
    );
  }
}

final class _SkeletonListTile extends StatelessWidget {
  const _SkeletonListTile();

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Skeleton(width: 48, height: 48, radius: 24),
      title: Skeleton(width: 140, height: 14, radius: 6),
      subtitle: Skeleton(width: 200, height: 12, radius: 6),
    );
  }
}
