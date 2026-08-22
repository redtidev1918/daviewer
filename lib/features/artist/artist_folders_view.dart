import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_error_state.dart';
import 'artist_providers.dart';

/// The artist's gallery folders (sub-galleries).
final class FoldersView extends ConsumerWidget {
  const FoldersView({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(artistFoldersProvider(username));
    final s = strings(ref.watch(appLanguageProvider));
    return folders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          AppErrorState(message: friendlyErrorMessage(error)),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(s.noFolders));
        }
        return GridView.builder(
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
                '/artist/$username/folder/${folder.id}?name=${Uri.encodeComponent(folder.name)}',
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
                              placeholder: (context, url) =>
                                  const ColoredBox(color: Color(0xffe9ecef)),
                              errorWidget: (context, url, error) =>
                                  const ColoredBox(
                                    color: Color(0xffe9ecef),
                                    child: Icon(Icons.folder),
                                  ),
                            )
                          : const ColoredBox(
                              color: Color(0xffe9ecef),
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
