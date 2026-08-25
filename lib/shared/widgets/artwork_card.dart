import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_theme.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sharing/app_share.dart';
import '../../features/artwork/artwork_store.dart';
import '../../features/artwork/favourite_actions.dart';

/// A clamped aspect ratio (width / height) for an artwork's display image,
/// used by masonry layouts to size cards at the image's natural shape.
double artworkAspectRatio(
  Artwork artwork, {
  double maxLandscapeAspectRatio = 2.0,
}) {
  for (final media in artwork.media) {
    if (media.kind == MediaKind.image &&
        media.width != null &&
        media.height != null &&
        media.height! > 0) {
      return (media.width! / media.height!).clamp(0.5, maxLandscapeAspectRatio);
    }
  }
  return 0.68;
}

/// Mobile two-column feeds give very wide images a little more height. The
/// thumbnail still uses [BoxFit.cover], so banner subjects remain legible
/// instead of becoming a thin strip behind the metadata overlay.
double artworkPreviewAspectRatio(BuildContext context, Artwork artwork) =>
    artworkAspectRatio(
      artwork,
      maxLandscapeAspectRatio: MediaQuery.sizeOf(context).width < 600
          ? 1.6
          : 2.0,
    );

bool usesCompactArtworkMetadata({
  required double width,
  required double height,
}) {
  if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
    return false;
  }
  return height < 120 || width / height >= 1.45;
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactMetadata = usesCompactArtworkMetadata(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
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
                  child: compactMetadata
                      ? _CompactArtworkMetadata(artwork: artwork)
                      : _RegularArtworkMetadata(artwork: artwork),
                ),
                if (hasVideo)
                  Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: compactMetadata ? 32 : 40,
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
      },
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
              leading: const Icon(Icons.share_outlined),
              title: Text(s.share),
              onTap: () async {
                Navigator.pop(context);
                await shareDeviantArtLink(
                  context,
                  uri: artwork.pageUri,
                  title: artwork.title,
                  strings: s,
                );
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

final class _CompactArtworkMetadata extends StatelessWidget {
  const _CompactArtworkMetadata({required this.artwork});

  final Artwork artwork;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.transparent, Color(0x75000000)],
      ),
    ),
    child: Row(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Text(
            artwork.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.15,
            ),
          ),
        ),
        if (artwork.author.username.isNotEmpty) ...<Widget>[
          const SizedBox(width: 6),
          Flexible(
            flex: 2,
            child: Text(
              '@${artwork.author.username}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                height: 1.15,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

final class _RegularArtworkMetadata extends StatelessWidget {
  const _RegularArtworkMetadata({required this.artwork});

  final Artwork artwork;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 22, 10, 8),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.transparent, Color(0x78000000)],
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
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        if (artwork.author.username.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Icon(
                Icons.person_outline,
                size: 12,
                color: Colors.white.withValues(alpha: 0.62),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  artwork.author.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}
