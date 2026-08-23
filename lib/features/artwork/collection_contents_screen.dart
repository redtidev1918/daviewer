import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/artwork_card.dart';

/// A simple native view of a collection's deviations. Used when the "More Like
/// This" preview already carries the collection's deviations; the full-contents
/// source (web reverse-engineering) plugs in behind the same screen later.
final class CollectionContentsScreen extends StatelessWidget {
  const CollectionContentsScreen({
    required this.title,
    required this.artworks,
    super.key,
  });

  final String title;
  final List<Artwork> artworks;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = (width / 200).round().clamp(2, 4);
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: MasonryGridView.count(
        padding: const EdgeInsets.all(12),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: artworks.length,
        itemBuilder: (context, index) {
          final artwork = artworks[index];
          return AspectRatio(
            aspectRatio: artworkAspectRatio(artwork),
            child: ArtworkCard(
              artwork: artwork,
              onTap: () => context.push('/artwork/${artwork.id}'),
            ),
          );
        },
      ),
    );
  }
}
