import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_card.dart';
import 'artwork_detail_providers.dart';
import 'artwork_navigation.dart';

/// "More from this artist" — a horizontal rail of the author's other recent
/// works. The most directly related "artist discovery" the official API
/// exposes cleanly; true cross-artist similarity lives in an undocumented
/// website recommendation stream (see `docs/architecture.md`).
///
/// Hides itself when the author has no other works or the gallery is
/// unavailable.
final class MoreFromArtistSection extends ConsumerWidget {
  const MoreFromArtistSection({required this.artworkId, super.key});

  final String artworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(moreFromArtistProvider(artworkId)).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final s = strings(ref.watch(appLanguageProvider));
    final author = ref
        .watch(artworkDetailProvider(artworkId))
        .valueOrNull
        ?.author
        .username;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Text(
          s.moreFromArtist(author ?? ''),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final artwork = items[index];
              return SizedBox(
                width: 140,
                child: ArtworkCard(
                  artwork: artwork,
                  onTap: () => openArtworkFromList(
                    context,
                    ref,
                    artworks: items,
                    artwork: artwork,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
