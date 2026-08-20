import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';

final class ArtworkCard extends StatelessWidget {
  const ArtworkCard({required this.artwork, this.onTap, super.key});

  final Artwork artwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Prefer a static image for the grid thumbnail; fall back to any media
    // (video / animation) so every card shows something.
    final media = artwork.media;
    final image = media.where((m) => m.kind == MediaKind.image).firstOrNull;
    final thumbnail = image ?? media.firstOrNull;
    final hasVideo = media.any((m) => m.kind == MediaKind.video);
    final hasAnimation = media.any((m) => m.kind == MediaKind.animation);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (thumbnail?.uri case final uri?)
                    CachedNetworkImage(
                      imageUrl: uri.toString(),
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          const ColoredBox(color: Color(0xffe9ecef)),
                      errorWidget: (context, url, error) =>
                          const ColoredBox(
                            color: Color(0xffe9ecef),
                            child: Icon(Icons.image),
                          ),
                    )
                  else
                    const ColoredBox(
                      color: Color(0xffe9ecef),
                      child: Icon(Icons.image),
                    ),
                  if (hasVideo)
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill,
                        size: 40,
                        color: Colors.white70,
                      ),
                    ),
                  if (hasAnimation)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'GIF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    artwork.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    artwork.author.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
