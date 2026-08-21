import 'dart:convert';

/// Converts a provider-authored HTML fragment to readable plain text.
///
/// DeviantArt descriptions arrive as HTML (`descriptionText.html.markup`, or
/// `deviation/content`), often with inline emoticon images, links, and block
/// formatting. Rendering that HTML directly is fragile, so the client extracts
/// plain text for display and keeps the links' visible labels.
String htmlToPlainText(String html) {
  var text = html;
  // Block boundaries become newlines so paragraphs stay readable.
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(
    RegExp(r'</(p|div|li|h[1-6]|tr)>', caseSensitive: false),
    '\n',
  );
  // Strip remaining tags and decode the common entities.
  text = text.replaceAll(RegExp(r'<[^>]*>'), '');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&hellip;', '…')
      .replaceAll('&mdash;', '—')
      .replaceAll('&ndash;', '–');
  // Collapse runs of spaces, but keep line breaks.
  text = text.replaceAll(RegExp(r'[ \t]+'), ' ');
  text = text.replaceAll(RegExp(r' *\n *'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

/// Extracts readable plain text from a tiptap document JSON string (the
/// `deviation/content` `original_markup` field), which DeviantArt uses for
/// descriptions when the rendered `html` field is empty.
String tiptapToPlainText(String json) {
  try {
    final decoded = jsonDecode(json);
    final buffer = StringBuffer();
    _walkTiptap(decoded, buffer);
    return buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  } on Object {
    return '';
  }
}

void _walkTiptap(Object? node, StringBuffer buffer) {
  if (node is Map) {
    final type = node['type'];
    final text = node['text'];
    if (type == 'text' && text is String) {
      buffer.write(text);
    }
    final content = node['content'];
    if (content is List) {
      for (final child in content) {
        _walkTiptap(child, buffer);
      }
    }
    if (type == 'paragraph' ||
        type == 'heading' ||
        type == 'listItem' ||
        type == 'blockquote') {
      buffer.write('\n');
    }
  } else if (node is List) {
    for (final child in node) {
      _walkTiptap(child, buffer);
    }
  }
}
