import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/artwork_card.dart';
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
    final results = _query.trim().isEmpty
        ? null
        : ref.watch(searchResultsProvider(_query.trim()));

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
      body: results == null
          ? const Center(child: Text('Type to search.'))
          : results.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('$error')),
              data: (artworks) => artworks.isEmpty
                  ? const Center(child: Text('No results found.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: artworks.length,
                      itemBuilder: (context, index) {
                        final artwork = artworks[index];
                        return ArtworkCard(
                          artwork: artwork,
                          onTap: () => context.go('/artwork/${artwork.id}'),
                        );
                      },
                    ),
            ),
    );
  }
}
