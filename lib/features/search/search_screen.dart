import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/search/search_history_store.dart';
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
  List<String> _history = const <String>[];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await SearchHistoryStore.load();
    if (mounted) setState(() => _history = history);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() => _query = query);
    final history = await SearchHistoryStore.add(query);
    if (mounted) setState(() => _history = history);
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final feed = query.isEmpty ? null : ref.watch(searchFeedProvider(query));
    final s = strings(ref.watch(appLanguageProvider));
    final isZh = ref.watch(appLanguageProvider) == AppLanguage.zh;

    return Scaffold(
      appBar: AppBar(
        title: Text(isZh ? '搜索' : 'Search'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: isZh ? '搜索 DeviantArt' : 'Search DeviantArt',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _submit,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _submit(_controller.text),
                  child: Text(isZh ? '搜索' : 'Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: feed == null
                ? _buildHistory(context, s, isZh)
                : ArtworkFeedGrid(
                    feed: feed,
                    emptyMessage: s.noResults,
                    onRefresh: () =>
                        ref.read(searchFeedProvider(query).notifier).refresh(),
                    onLoadMore: () => ref
                        .read(searchFeedProvider(query).notifier)
                        .loadMore(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context, AppStrings s, bool isZh) {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.search, size: 48, color: Colors.grey),
            const SizedBox(height: 8),
            Text(isZh ? '输入关键词搜索 DeviantArt 作品' : 'Search artworks'),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Text(
                isZh ? '搜索记录' : 'Recent',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await SearchHistoryStore.clear();
                  if (mounted) setState(() => _history = const <String>[]);
                },
                child: Text(isZh ? '清除' : 'Clear'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final item in _history)
                ActionChip(
                  label: Text(item),
                  avatar: const Icon(Icons.history, size: 16),
                  onPressed: () {
                    _controller.text = item;
                    _submit(item);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
