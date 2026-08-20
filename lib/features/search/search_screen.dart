import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/artwork_feed_grid.dart';
import 'search_providers.dart';

final class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

final class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final feed = query.isEmpty ? null : ref.watch(searchFeedProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search DeviantArt',
            border: InputBorder.none,
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) => setState(() => _query = value),
        ),
      ),
      body: feed == null
          ? const Center(child: Text('Type to search.'))
          : ArtworkFeedGrid(
              feed: feed,
              emptyMessage: 'No results found.',
              onRefresh: () =>
                  ref.read(searchFeedProvider(query).notifier).refresh(),
              onLoadMore: () =>
                  ref.read(searchFeedProvider(query).notifier).loadMore(),
            ),
    );
  }
}
