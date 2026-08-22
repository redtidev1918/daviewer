import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import 'artwork_detail_providers.dart';

/// A horizontal "More Like This" strip shown below an artwork, listing related
/// deviations. Hides itself when there is nothing to show.
final class MoreLikeThisSection extends ConsumerWidget {
  const MoreLikeThisSection({required this.artworkId, super.key});

  final String artworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final related = ref.watch(moreLikeThisProvider(artworkId));

    return related.when(
      loading: () => const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              s.moreLikeThis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _RelatedCard(artwork: items[index]),
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _RelatedCard extends StatelessWidget {
  const _RelatedCard({required this.artwork});

  final Artwork artwork;

  @override
  Widget build(BuildContext context) {
    final image = artwork.media
        .where((m) => m.kind == MediaKind.image)
        .firstOrNull;
    final url =
        image?.uri?.toString() ?? artwork.media.firstOrNull?.uri?.toString();

    return GestureDetector(
      onTap: () => context.push('/artwork/${artwork.id}'),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url == null
                    ? const ColoredBox(
                        color: AppTheme.placeholderColor,
                        child: Icon(Icons.image_outlined),
                      )
                    : CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheWidth: 320,
                        errorWidget: (context, url, error) => const ColoredBox(
                          color: AppTheme.placeholderColor,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              artwork.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
