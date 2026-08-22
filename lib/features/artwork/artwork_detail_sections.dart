import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';

/// The artwork title and author link.
final class ArtworkHeader extends StatelessWidget {
  const ArtworkHeader({required this.artwork, required this.s, super.key});

  final Artwork artwork;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(artwork.title, style: Theme.of(context).textTheme.headlineSmall),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.push('/artist/${artwork.author.username}'),
            child: Text('${s.byPrefix}${artwork.author.username}'),
          ),
        ),
      ],
    );
  }
}

/// The description / journal body, rendered as rich HTML when available and as
/// plain text otherwise. Renders nothing when there is no content.
final class ArtworkDescriptionSection extends StatelessWidget {
  const ArtworkDescriptionSection({
    required this.isJournal,
    required this.s,
    required this.onOpenLink,
    this.journalHtml,
    this.descriptionHtml,
    this.description,
    super.key,
  });

  final bool isJournal;
  final AppStrings s;
  final void Function(String? url) onOpenLink;
  final String? journalHtml;
  final String? descriptionHtml;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    if (isJournal && journalHtml != null && journalHtml!.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.bodyText, style: titleStyle),
          const SizedBox(height: 8),
          Html(
            data: journalHtml!,
            onLinkTap: (url, attributes, element) => onOpenLink(url),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    if (!isJournal &&
        descriptionHtml != null &&
        descriptionHtml!.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(s.description, style: titleStyle),
          const SizedBox(height: 8),
          Html(
            data: descriptionHtml!,
            onLinkTap: (url, attributes, element) => onOpenLink(url),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    if (description != null && description!.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(isJournal ? s.bodyText : s.description, style: titleStyle),
          const SizedBox(height: 8),
          SelectableText(
            description!,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}

/// The searchable tag chips.
final class ArtworkTagsSection extends StatelessWidget {
  const ArtworkTagsSection({required this.tags, super.key});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Divider(),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: <Widget>[
            for (final tag in tags)
              ActionChip(
                label: Text('#$tag'),
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    context.push('/tag/${Uri.encodeComponent(tag)}'),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
