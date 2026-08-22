import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/search/search_history_store.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import '../../shared/widgets/settings_action.dart';
import 'search_providers.dart';

const List<String> _popularTags = <String>[
  'digitalart',
  'fanart',
  'anime',
  'manga',
  'photography',
  'traditionalart',
  'landscape',
  'portrait',
  'characterdesign',
  'pixelart',
];

final class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

final class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<String> _history = const <String>[];
  int _mode = 0; // 0 = artworks, 1 = users

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
    // '#tag' → browse by tag.
    if (query.startsWith('#')) {
      final tag = query.substring(1).trim();
      if (tag.isNotEmpty) {
        unawaited(context.push('/tag/${Uri.encodeComponent(tag)}'));
        return;
      }
    }
    setState(() => _query = query);
    final history = await SearchHistoryStore.add(query);
    if (mounted) setState(() => _history = history);
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final s = strings(ref.watch(appLanguageProvider));

    return Scaffold(
      appBar: AppBar(
        title: Text(s.search),
        actions: const <Widget>[SettingsAction()],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _controller,
              autofocus: false,
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: s.clear,
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                if (value.trim().isEmpty && _query.isNotEmpty) {
                  setState(() => _query = '');
                }
              },
              onSubmitted: _submit,
            ),
          ),
          if (query.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: SegmentedButton<int>(
                segments: <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text(s.artworks)),
                  ButtonSegment<int>(value: 1, label: Text(s.users)),
                ],
                selected: <int>{_mode},
                onSelectionChanged: (selection) =>
                    setState(() => _mode = selection.first),
              ),
            ),
          Expanded(
            child: query.isEmpty
                ? _buildIdle(context, s)
                : _mode == 0
                ? ArtworkFeedGrid(
                    feed: ref.watch(searchFeedProvider(query)),
                    emptyMessage: s.noResults,
                    onRefresh: () =>
                        ref.read(searchFeedProvider(query).notifier).refresh(),
                    onLoadMore: () =>
                        ref.read(searchFeedProvider(query).notifier).loadMore(),
                  )
                : _UserResults(query: query),
          ),
        ],
      ),
    );
  }

  Widget _buildIdle(BuildContext context, AppStrings s) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            s.popularTags,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              for (final tag in _popularTags)
                ActionChip(
                  label: Text('#$tag'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      context.push('/tag/${Uri.encodeComponent(tag)}'),
                ),
            ],
          ),
        ),
        const Divider(),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              s.searchIdleHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: <Widget>[
                Text(s.recent, style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    await SearchHistoryStore.clear();
                    if (mounted) {
                      setState(() => _history = const <String>[]);
                    }
                  },
                  child: Text(s.clearHistory),
                ),
              ],
            ),
          ),
          for (final item in _history)
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(item),
              onTap: () {
                _controller.text = item;
                _submit(item);
              },
            ),
        ],
      ],
    );
  }
}

final class _UserResults extends ConsumerWidget {
  const _UserResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userSearchProvider(query));
    final s = strings(ref.watch(appLanguageProvider));
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          AppErrorState(message: friendlyErrorMessage(error)),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(s.noUsersFound));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = items[index];
            return ListTile(
              leading: user.avatarUri == null
                  ? const CircleAvatar(child: Icon(Icons.person))
                  : CircleAvatar(
                      foregroundImage: NetworkImage(user.avatarUri.toString()),
                    ),
              title: Text(user.username),
              subtitle: user.displayName == null
                  ? null
                  : Text(user.displayName!),
              onTap: () => context.push('/artist/${user.username}'),
            );
          },
        );
      },
    );
  }
}
