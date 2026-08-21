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
