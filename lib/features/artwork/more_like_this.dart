import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/web_session_controller.dart';
import '../../core/auth/web_session_refresher.dart';
import '../../core/diagnostics/app_logger.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_card.dart';
import 'artwork_detail_providers.dart';
import 'artwork_navigation.dart';

/// A masonry (waterfall) grid of "More Like This" deviations shown below an
/// artwork, matching the modern feed layout. Hides itself when empty.
///
/// This is the reference pattern for related-content sections: a self-contained
/// widget that owns its provider and handles loading/error/empty internally.
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
      error: (error, stackTrace) {
        debugPrint('[moreLikeThis] $artworkId failed: $error');
        AppLogger.instance.error(
          'moreLikeThis',
          'failed for $artworkId',
          error,
          stackTrace,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              s.moreLikeThis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: Text(s.moreLikeThisLoadFailed)),
                TextButton.icon(
                  onPressed: () => _retry(context, ref),
                  icon: const Icon(Icons.refresh),
                  label: Text(s.retry),
                ),
              ],
            ),
          ],
        );
      },
      data: (result) {
        final items = result.artworks;
        if (items.isEmpty) {
          AppLogger.instance.warning(
            'moreLikeThis',
            'empty related result for $artworkId',
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                s.moreLikeThis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(Icons.auto_awesome_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.noMoreLikeThis)),
                  TextButton.icon(
                    onPressed: () => _retry(context, ref),
                    icon: const Icon(Icons.refresh),
                    label: Text(s.retry),
                  ),
                ],
              ),
            ],
          );
        }
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
          ],
        );
      },
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    // Numeric web-feed ids need a current web CSRF token before they can be
    // resolved to the UUID accepted by the official endpoint. Await the real
    // headless refresh completion, then invalidate the whole resolution chain.
    if (isNumericDeviationId(artworkId) &&
        ref.read(webSessionControllerProvider).signedIn) {
      await ref.read(webSessionRefresherProvider).refresh();
    }
    if (!context.mounted) return;
    ref.invalidate(deviationInitProvider(artworkId));
    ref.invalidate(artworkUuidProvider(artworkId));
    ref.invalidate(moreLikeThisProvider(artworkId));
  }
}
