import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import 'artwork_detail_providers.dart';

/// A horizontal rail of collection cards ("featured in" / "suggested"
/// collections) shown below the More Like This grid on the detail screen.
///
/// Both sections read [moreLikeThisProvider] alongside the artwork grid, so the
/// preview endpoint is fetched once for all three. Each section is
/// self-contained and hides itself when it has nothing to show — the same
/// reference pattern as `MoreLikeThisSection`.
final class FeaturedInCollectionsSection extends ConsumerWidget {
  const FeaturedInCollectionsSection({required this.artworkId, super.key});

  final String artworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref
        .watch(moreLikeThisProvider(artworkId))
        .valueOrNull
        ?.featuredInCollections;
    if (groups == null || groups.isEmpty) return const SizedBox.shrink();
    final s = strings(ref.watch(appLanguageProvider));
    return _CollectionRail(
      title: s.featuredInCollections,
      groups: groups,
      s: s,
    );
  }
}

final class SuggestedCollectionsSection extends ConsumerWidget {
  const SuggestedCollectionsSection({required this.artworkId, super.key});

  final String artworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref
        .watch(moreLikeThisProvider(artworkId))
        .valueOrNull
        ?.suggestedCollections;
    if (groups == null || groups.isEmpty) return const SizedBox.shrink();
    final s = strings(ref.watch(appLanguageProvider));
    return _CollectionRail(title: s.suggestedCollections, groups: groups, s: s);
  }
}

final class _CollectionRail extends StatelessWidget {
  const _CollectionRail({
    required this.title,
    required this.groups,
    required this.s,
  });

  final String title;
  final List<CollectionWithDeviations> groups;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: 24),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: groups.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _CollectionCard(group: groups[index], s: s),
          ),
        ),
      ],
    );
  }
}

final class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.group, required this.s});

  final CollectionWithDeviations group;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final collection = group.collection;
    final cover = _collectionCover(group);
    return SizedBox(
      width: 168,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final uri = collection.owner.profileUri;
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (cover != null)
                CachedNetworkImage(
                  imageUrl: cover.toString(),
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  placeholder: (context, url) =>
                      const ColoredBox(color: AppTheme.placeholderColor),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: AppTheme.placeholderColor,
                    child: Icon(Icons.collections_outlined),
                  ),
                )
              else
                const ColoredBox(
                  color: AppTheme.placeholderColor,
                  child: Icon(Icons.collections_outlined),
                ),
              // Collection name + owner overlaid on a bottom gradient.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 28, 10, 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[Colors.transparent, Colors.black87],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        collection.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.byPrefix}${collection.owner.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first static image in a collection group's deviations, used as the
/// collection card's cover.
Uri? _collectionCover(CollectionWithDeviations group) {
  for (final artwork in group.deviations) {
    for (final media in artwork.media) {
      if (media.kind == MediaKind.image && media.uri != null) {
        return media.uri;
      }
    }
  }
  return null;
}
