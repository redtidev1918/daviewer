import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import '../../shared/widgets/skeleton.dart';
import 'artist_folders_view.dart';
import 'artist_header.dart';
import 'artist_journals_view.dart';
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
      final watching = await OfficialUserRepository(runtime.transport!)
          .isWatching(widget.username);
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
        final message = friendlyErrorMessage(error);
        final isForbidden =
            message.contains('403') ||
            message.contains('authorization') ||
            message.contains('Forbidden');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isForbidden
                  ? strings(ref.read(appLanguageProvider)).permissionDeniedWatch
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
                label: Text(_watching ? s.watchStateOn : s.watchStateOff),
              ),
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: s.gallery),
              Tab(text: s.favourites),
              Tab(text: s.journal),
              Tab(text: s.folders),
            ],
          ),
        ),
        body: profile.when(
          loading: () => const SkeletonDetail(),
          error: (error, stackTrace) =>
              AppErrorState(message: friendlyErrorMessage(error)),
          data: (profile) => Column(
            children: <Widget>[
              ArtistHeader(profile: profile),
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
                    JournalsView(username: widget.username),
                    FoldersOverviewView(username: widget.username),
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
