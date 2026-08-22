import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_card.dart';
import 'artwork_detail_providers.dart';

/// A masonry (waterfall) grid of "More Like This" deviations shown below an
/// artwork, matching the modern feed layout. Hides itself when empty.
///
/// This is the reference pattern for related-content sections: a self-contained
/// widget that owns its provider, handles loading/error/empty internally, and
/// hides itself when there is nothing to show. Future sections (e.g. Suggested
/// Deviants / Suggested Collections) follow the same shape and plug into the
/// detail screen's section list without touching other sections.
final class MoreLikeThisSection extends ConsumerWidget {
  const MoreLikeThisSection({required this.artworkId, super.key});

  final String artworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final related = ref.watch(moreLikeThisProvider(artworkId));

    return related.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (result) {
        final items = result.artworks;
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              s.moreLikeThis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            MasonryGridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final artwork = items[index];
                return AspectRatio(
                  aspectRatio: artworkAspectRatio(artwork),
                  child: ArtworkCard(
                    artwork: artwork,
                    onTap: () => context.push('/artwork/${artwork.id}'),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
