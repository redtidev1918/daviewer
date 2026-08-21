import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import 'artist_providers.dart';

final class ArtistScreen extends ConsumerStatefulWidget {
  const ArtistScreen({required this.username, super.key});

  final String username;

  @override
  ConsumerState<ArtistScreen> createState() => _ArtistScreenState();
}

final class _ArtistScreenState extends ConsumerState<ArtistScreen> {
  bool _watching = false;
  bool _watchBusy = false;

  @override
  void initState() {
    super.initState();
    _loadWatchState();
  }

  Future<void> _loadWatchState() async {
    try {
      final runtime = ref.read(runtimeProvider);
      final watching = await OfficialUserRepository(
        runtime.transport!,
      ).isWatching(widget.username);
      if (mounted) {
        setState(() {
          _watching = watching;
        });
      }
    } on Object {
      // Ignore: the watch state is best-effort and the button still works.
    }
  }

  Future<void> _toggleWatch() async {
    if (_watchBusy) return;
    setState(() => _watchBusy = true);
    try {
      final runtime = ref.read(runtimeProvider);
      final social = OfficialSocialRepository(runtime.transport!);
      if (_watching) {
        await social.unwatch(widget.username);
      } else {
        await social.watch(widget.username);
      }
      if (mounted) setState(() => _watching = !_watching);
    } on Object catch (error) {
      if (mounted) {
        final message = '$error';
        final isForbidden = message.contains('403') ||
            message.contains('authorization') ||
            message.contains('Forbidden');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isForbidden
                  ? '权限不足，请退出登录后重新登录以获取关注权限。'
                  : message,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _watchBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(artistProfileProvider(widget.username));
    final galleryFeed = ref.watch(artistGalleryProvider(widget.username));
    final favouritesFeed = ref.watch(artistFavouritesProvider(widget.username));
    final s = strings(ref.watch(appLanguageProvider));
    final isZh = ref.watch(appLanguageProvider) == AppLanguage.zh;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.username),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonalIcon(
                onPressed: _watchBusy ? null : _toggleWatch,
                icon: Icon(
                  _watching ? Icons.check : Icons.person_add_alt_1,
                  size: 18,
                ),
                label: Text(_watching ? '已关注' : '关注'),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: s.gallery),
              Tab(text: s.favourites),
              Tab(text: isZh ? '文章' : 'Journal'),
              Tab(text: isZh ? '画集' : 'Folders'),
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
                      emptyMessage: s.noArtworks,
                      onRefresh: () => ref
                          .read(artistGalleryProvider(widget.username).notifier)
                          .refresh(),
                      onLoadMore: () => ref
                          .read(artistGalleryProvider(widget.username).notifier)
                          .loadMore(),
                    ),
                    ArtworkFeedGrid(
                      feed: favouritesFeed,
                      emptyMessage: s.noFavourites,
                      onRefresh: () => ref
                          .read(
                            artistFavouritesProvider(widget.username).notifier,
                          )
                          .refresh(),
                      onLoadMore: () => ref
                          .read(
                            artistFavouritesProvider(widget.username).notifier,
                          )
                          .loadMore(),
                    ),
                    _JournalsView(username: widget.username),
                    _FoldersView(username: widget.username),
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

final class _JournalsView extends ConsumerWidget {
  const _JournalsView({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(artistJournalsProvider(username));
    return journals.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('暂无文章'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final journal = items[index];
            return ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(
                journal.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: journal.publishedAt == null
                  ? null
                  : Text(_formatDate(journal.publishedAt!)),
              onTap: () => context.push('/artwork/${journal.id}'),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime time) {
    final local = time.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

final class _FoldersView extends ConsumerWidget {
  const _FoldersView({required this.username});

  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(artistFoldersProvider(username));
    return folders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('暂无画集'));
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
            final thumbUri = folder.thumbnail?.media.firstOrNull?.uri;
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
                      child: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
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
