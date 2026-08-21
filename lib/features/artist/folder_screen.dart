import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/artwork_feed_grid.dart';
import 'artist_providers.dart';

/// The contents of a single artist gallery folder.
final class FolderScreen extends ConsumerWidget {
  const FolderScreen({
    required this.username,
    required this.folderId,
    required this.folderName,
    super.key,
  });

  final String username;
  final String folderId;
  final String folderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final request = FolderRequest(username: username, folderId: folderId);
    final feed = ref.watch(folderContentsProvider(request));
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: ArtworkFeedGrid(
        feed: feed,
        emptyMessage: '空画集',
        onRefresh: () => ref.read(folderContentsProvider(request).notifier).refresh(),
        onLoadMore: () => ref.read(folderContentsProvider(request).notifier).loadMore(),
      ),
    );
  }
}
