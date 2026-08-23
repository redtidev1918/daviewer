import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_feed_grid.dart';
import '../../shared/widgets/compact_tag_strip.dart';
import '../../shared/widgets/settings_action.dart';
import 'search_providers.dart';
import 'search_user_results.dart';

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
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  int _mode = 0; // 0 = artworks, 1 = users

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    // '#tag' → browse by tag.
    if (query.startsWith('#')) {
      final tag = query.substring(1).trim();
      if (tag.isNotEmpty) {
        context.push('/tag/${Uri.encodeComponent(tag)}');
        return;
      }
    }
    _debounce?.cancel();
    setState(() => _query = query);
    ref.read(searchHistoryProvider.notifier).add(query);
  }

  /// Live search: results appear as the user types, debounced so a rapid burst
  /// of keystrokes triggers only one request. `#tag` navigation and search
  /// history are still commit-time actions (enter / history tap), not live.
  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _query = '');
      return;
    }
    if (query.startsWith('#')) return;
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (_query != query) setState(() => _query = query);
    });
  }

  void _selectFromHistory(String query) {
    _controller.text = query;
    _submit(query);
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
              onChanged: _onChanged,
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
                ? _SearchIdleView(onSelect: _selectFromHistory)
                : _mode == 0
                ? ArtworkFeedGrid(
                    feed: ref.watch(searchFeedProvider(query)),
                    emptyMessage: s.noResults,
                    onRefresh: () =>
                        ref.read(searchFeedProvider(query).notifier).refresh(),
                    onLoadMore: () =>
                        ref.read(searchFeedProvider(query).notifier).loadMore(),
                  )
                : UserResults(query: query),
          ),
        ],
      ),
    );
  }
}

/// The idle search view: recommended tags, popular tags, and recent history.
final class _SearchIdleView extends ConsumerWidget {
  const _SearchIdleView({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);
    final recommended = ref.watch(recommendedTagsProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: <Widget>[
        if (recommended.isNotEmpty) ...[
          _SectionTitle(text: s.recommendedTags),
          _TagChips(tags: recommended),
          const Divider(),
        ],
        _SectionTitle(text: s.popularTags),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          child: Text(
            s.popularTagsHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        _TagChips(tags: _popularTags),
        const Divider(),
        _SearchHistorySection(onSelect: onSelect),
      ],
    );
  }
}

/// A section header.
final class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

/// A compact, horizontally scrollable row of tappable tags.
final class _TagChips extends StatelessWidget {
  const _TagChips({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return CompactTagStrip(
      tags: tags,
      onSelected: (tag) => context.push('/tag/${Uri.encodeComponent(tag)}'),
    );
  }
}

/// The recent-search history list (with per-item delete and clear-all).
final class _SearchHistorySection extends ConsumerWidget {
  const _SearchHistorySection({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);
    final history = ref.watch(searchHistoryProvider);

    if (history.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        child: Column(
          children: <Widget>[
            Icon(Icons.search, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              s.searchIdleHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: <Widget>[
              Text(s.recent, style: theme.textTheme.titleSmall),
              const Spacer(),
              TextButton(
                onPressed: () =>
                    ref.read(searchHistoryProvider.notifier).clear(),
                child: Text(s.clearHistory),
              ),
            ],
          ),
        ),
        for (final item in history)
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(item),
            trailing: IconButton(
              tooltip: s.clear,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(searchHistoryProvider.notifier).remove(item),
            ),
            onTap: () => onSelect(item),
          ),
      ],
    );
  }
}
