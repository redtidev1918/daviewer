import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/artwork_card.dart';
import 'home_providers.dart';

final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 400) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(runtimeProvider);
    final auth = ref.watch(authControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('DA Viewer'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Search',
              onPressed: () => context.go('/search'),
              icon: const Icon(Icons.search),
            ),
            if (auth.status == AuthStatus.signedOut)
              IconButton(
                tooltip: 'Login',
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login),
              )
            else if (auth.status == AuthStatus.signedIn)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'favourites') {
                    context.go('/favourites');
                  } else if (value == 'downloads') {
                    context.go('/downloads');
                  } else if (value == 'logout') {
                    ref.read(authControllerProvider.notifier).logout();
                  }
                },
                itemBuilder: (context) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'favourites',
                    child: Text('Favourites'),
                  ),
                  PopupMenuItem<String>(
                    value: 'downloads',
                    child: Text('Downloads'),
                  ),
                  PopupMenuItem<String>(value: 'logout', child: Text('Logout')),
                ],
              ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Home'),
              Tab(text: 'Daily'),
            ],
          ),
        ),
        body: !runtime.isConfigured
            ? const Center(child: Text('Pass DAKIT_CLIENT_ID at build time.'))
            : const TabBarView(children: <Widget>[_HomeFeed(), _DailyFeed()]),
      ),
    );
  }
}

final class _HomeFeed extends ConsumerWidget {
  const _HomeFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider);
    return RefreshIndicator(
      onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
      child: _ArtworkGrid(
        scrollController: context
            .findAncestorStateOfType<_HomeScreenState>()
            ?._scrollController,
        items: feed.items,
        isLoading: feed.isLoading,
        error: feed.error,
        emptyMessage: 'No artworks found.',
      ),
    );
  }
}

final class _DailyFeed extends ConsumerWidget {
  const _DailyFeed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(dailyDeviationsProvider);
    return daily.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(child: Text('$error')),
      data: (items) => _ArtworkGrid(
        items: items,
        isLoading: false,
        error: null,
        emptyMessage: 'No daily deviations found.',
      ),
    );
  }
}

final class _ArtworkGrid extends StatelessWidget {
  const _ArtworkGrid({
    required this.items,
    required this.isLoading,
    required this.error,
    required this.emptyMessage,
    this.scrollController,
  });

  final List<Artwork> items;
  final bool isLoading;
  final Object? error;
  final String emptyMessage;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (error != null && items.isEmpty) {
      return ListView(
        children: <Widget>[
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Center(child: Text('$error')),
          ),
        ],
      );
    }
    if (items.isEmpty && isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return ListView(
        children: <Widget>[
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Center(child: Text(emptyMessage)),
          ),
        ],
      );
    }

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length + (isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final artwork = items[index];
        return ArtworkCard(
          artwork: artwork,
          onTap: () => context.go('/artwork/${artwork.id}'),
        );
      },
    );
  }
}
