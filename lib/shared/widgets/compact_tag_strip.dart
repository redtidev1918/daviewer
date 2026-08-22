import 'package:flutter/material.dart';

/// A single-line, horizontally scrollable tag list.
///
/// Tags are navigation metadata, not primary actions. Keeping them to one
/// compact row prevents long tag sets from consuming most of an artwork or
/// search screen while preserving access to every tag.
final class CompactTagStrip extends StatelessWidget {
  const CompactTagStrip({
    required this.tags,
    required this.onSelected,
    this.leading,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    super.key,
  });

  final List<String> tags;
  final ValueChanged<String> onSelected;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: tags.length + (leading == null ? 0 : 1),
        separatorBuilder: (context, index) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final prefix = leading;
          if (prefix != null && index == 0) {
            return Center(child: prefix);
          }
          final tag = tags[index - (prefix == null ? 0 : 1)];
          return Center(
            child: _CompactTag(tag: tag, onPressed: () => onSelected(tag)),
          );
        },
      ),
    );
  }
}

final class _CompactTag extends StatelessWidget {
  const _CompactTag({required this.tag, required this.onPressed});

  final String tag;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          child: Text(
            '#$tag',
            maxLines: 1,
            style: theme.textTheme.labelMedium?.copyWith(height: 1.1),
          ),
        ),
      ),
    );
  }
}
