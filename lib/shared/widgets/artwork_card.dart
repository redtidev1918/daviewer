import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';

final class ArtworkCard extends StatelessWidget {
  const ArtworkCard({required this.artwork, this.onTap, super.key});

  final Artwork artwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = artwork.media.isNotEmpty
        ? artwork.media.first.uri.toString()
        : null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: imageUrl == null
                  ? const ColoredBox(
                      color: Color(0xffe9ecef),
                      child: Icon(Icons.image),
                    )
                  : CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          const ColoredBox(color: Color(0xffe9ecef)),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.image),
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
