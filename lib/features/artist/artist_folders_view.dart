import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/skeleton.dart';
import 'artist_providers.dart';

/// The artist's gallery folders (sub-galleries) or favourites collections.
final class FoldersView extends ConsumerWidget {
  const FoldersView({
    required this.username,
    this.kind = FolderKind.gallery,
    this.shrinkWrap = false,
    super.key,
  });

  final String username;
  final FolderKind kind;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(
      kind == FolderKind.collection
          ? artistFavouriteFoldersProvider(username)
          : artistFoldersProvider(username),
    );
    final s = strings(ref.watch(appLanguageProvider));
    return folders.when(
      loading: () => shrinkWrap
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          : const SkeletonList(),
      error: (error, stackTrace) =>
          AppErrorState(message: friendlyErrorMessage(error)),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(s.noFolders));
        }
        return GridView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap
              ? const NeverScrollableScrollPhysics()
              : const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final folder = items[index];
            // Pick the smallest image (the thumbnail) — `media.first` is the
            // full-size `content` and would make the grid painfully slow.
            final thumbUri = folder.thumbnail?.media
                .where((m) => m.kind == MediaKind.image)
                .fold<MediaAsset?>(
                  null,
                  (best, m) =>
                      best == null || (m.width ?? 0) < (best.width ?? 0)
                      ? m
                      : best,
                )
                ?.uri;
            return InkWell(
              onTap: () => context.push(
                '/artist/$username/folder/${folder.id}'
                '?name=${Uri.encodeComponent(folder.name)}'
                '&kind=${kind == FolderKind.collection ? 'collection' : 'gallery'}',
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: thumbUri != null
                          ? CachedNetworkImage(
                              imageUrl: thumbUri.toString(),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (context, url) => const ColoredBox(
                                color: AppTheme.placeholderColor,
                              ),
                              errorWidget: (context, url, error) =>
                                  const ColoredBox(
                                    color: AppTheme.placeholderColor,
                                    child: Icon(Icons.folder),
                                  ),
                            )
                          : const ColoredBox(
                              color: AppTheme.placeholderColor,
                              child: Icon(Icons.folder),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            folder.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            folder.size == null || folder.size == 0
                                ? s.emptyFolderBadge
                                : s.folderArtworkCount(folder.size!),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A combined "Categories" view listing the artist's gallery folders and
/// favourites collections in one scrollable page, so the artist screen needs
/// only a single folders tab instead of two confusingly named ones.
final class FoldersOverviewView extends ConsumerWidget {
  const FoldersOverviewView({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final titleStyle = Theme.of(context).textTheme.titleSmall;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: <Widget>[
        Text(s.galleryFolders, style: titleStyle),
        const SizedBox(height: 8),
        FoldersView(
          username: username,
          kind: FolderKind.gallery,
          shrinkWrap: true,
        ),
        const SizedBox(height: 16),
        Text(s.favouriteFolders, style: titleStyle),
        const SizedBox(height: 8),
        FoldersView(
          username: username,
          kind: FolderKind.collection,
          shrinkWrap: true,
        ),
      ],
    );
  }
}
