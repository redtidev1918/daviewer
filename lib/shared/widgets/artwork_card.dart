import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../features/artwork/artwork_store.dart';
import '../../features/artwork/favourite_actions.dart';

/// A clamped aspect ratio (width / height) for an artwork's display image,
/// used by masonry layouts to size cards at the image's natural shape.
double artworkAspectRatio(Artwork artwork) {
  for (final media in artwork.media) {
    if (media.kind == MediaKind.image &&
        media.width != null &&
        media.height != null &&
        media.height! > 0) {
      return (media.width! / media.height!).clamp(0.5, 2.0);
    }
  }
  return 0.68;
}

final class ArtworkCard extends ConsumerWidget {
  const ArtworkCard({required this.artwork, this.onTap, super.key});

  final Artwork artwork;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    // Track the favourite flag through the store so a favourite action here is
    // reflected immediately (and mirrored in the detail screen).
    final favourited = ref.watch(
      artworkStoreProvider.select(
        (map) => map[artwork.id]?.isFavourited ?? artwork.isFavourited,
      ),
    );
    // Prefer a static image for the grid thumbnail; fall back to any media
    // (video / animation) so every card shows something.
    final media = artwork.media;
    final image = media.where((m) => m.kind == MediaKind.image).firstOrNull;
    final thumbnail = image ?? media.firstOrNull;
    final hasVideo = media.any((m) => m.kind == MediaKind.video);
    // Animated GIFs are mapped as image assets with an `image/gif` MIME type
    // (or a `.gif` URL), not always as MediaKind.animation — cover all three
    // so the badge shows for every GIF work in the feed.
    final hasGif = media.any(
      (m) =>
          m.kind == MediaKind.animation ||
          m.mimeType == 'image/gif' ||
          (m.uri?.path.toLowerCase().endsWith('.gif') ?? false),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: () => _showCardMenu(context, ref, favourited),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (thumbnail?.uri case final uri?)
              Hero(
                tag: 'artwork-${artwork.id}',
                child: CachedNetworkImage(
                  imageUrl: uri.toString(),
                  fit: BoxFit.cover,
                  memCacheWidth: 480,
                  placeholder: (context, url) =>
                      const ColoredBox(color: AppTheme.placeholderColor),
                  errorWidget: (context, url, error) => const ColoredBox(
                    color: AppTheme.placeholderColor,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              )
            else
              const ColoredBox(
                color: AppTheme.placeholderColor,
                child: Icon(Icons.image_outlined),
              ),
            // Title + author overlaid on a light bottom gradient. The title is
            // semi-transparent so a long title never hides the artwork; the
            // lighter gradient keeps the card looking airy instead of a solid
            // dark block.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 24, 10, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Colors.black45],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      artwork.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.person_outline,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            artwork.author.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (hasVideo)
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  size: 40,
                  color: Colors.white70,
                ),
              ),
            if (hasGif)
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
            if (artwork.isMultiMedia)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.filter_none,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        s.multiImageBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCardMenu(BuildContext context, WidgetRef ref, bool favourited) {
    final s = strings(ref.read(appLanguageProvider));
    final url = artwork.pageUri.toString();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: Text(s.viewDetail),
              onTap: () {
                Navigator.pop(context);
                onTap?.call();
              },
            ),
            ListTile(
              leading: Icon(
                favourited ? Icons.favorite : Icons.favorite_border,
              ),
              title: Text(favourited ? s.unfavourite : s.favourite),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final now = await setArtworkFavourite(
                    ref,
                    artwork.id,
                    !favourited,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          now ? s.favouritedToast : s.unfavouritedToast,
                        ),
                      ),
                    );
                  }
                } on Object catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(friendlyErrorMessage(error))),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(s.copyLink),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(s.linkCopied)));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(s.openInBrowser),
              onTap: () {
                Navigator.pop(context);
                final uri = Uri.tryParse(url);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
