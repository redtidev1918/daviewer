import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/artwork_feed_grid.dart';
import 'artist_providers.dart';

final class ArtistScreen extends ConsumerWidget {
  const ArtistScreen({required this.username, super.key});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(artistProfileProvider(username));
    final galleryFeed = ref.watch(artistGalleryProvider(username));
    final favouritesFeed = ref.watch(artistFavouritesProvider(username));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(username),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Gallery'),
              Tab(text: 'Favourites'),
            ],
          ),
        ),
        body: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text('$error')),
          data: (profile) => Column(
            children: <Widget>[
              _ArtistHeader(profile: profile),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    ArtworkFeedGrid(
                      feed: galleryFeed,
                      emptyMessage: 'No artworks found.',
                      onRefresh: () => ref
                          .read(artistGalleryProvider(username).notifier)
                          .refresh(),
                      onLoadMore: () => ref
                          .read(artistGalleryProvider(username).notifier)
                          .loadMore(),
                    ),
                    ArtworkFeedGrid(
                      feed: favouritesFeed,
                      emptyMessage: 'No favourites found.',
                      onRefresh: () => ref
                          .read(artistFavouritesProvider(username).notifier)
                          .refresh(),
                      onLoadMore: () => ref
                          .read(artistFavouritesProvider(username).notifier)
                          .loadMore(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ArtistHeader extends StatelessWidget {
  const _ArtistHeader({required this.profile});

  final UserProfileDetails profile;

  @override
  Widget build(BuildContext context) {
    final avatar = profile.user.avatarUri;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xffe9ecef),
            foregroundImage: avatar == null
                ? null
                : CachedNetworkImageProvider(avatar.toString()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  profile.user.displayName ?? profile.user.username,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (profile.realName case final realName?) Text(realName),
                Text(
                  '${profile.stats.deviations} deviations · '
                  '${profile.stats.favourites} favourites',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
