import 'dart:convert';

import 'wix_media.dart';

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
/// `deviation/content` `original_markup` field, or `descriptionText.html.markup`
/// when its type is `tiptap`), which DeviantArt uses for descriptions when the
/// rendered `html` field is empty.
String tiptapToPlainText(String json) {
  try {
    final decoded = jsonDecode(json);
    // Some payloads wrap the doc as {"version":..., "document":{...}}.
    Object? document = decoded;
    if (decoded is Map && decoded['document'] is Map) {
      document = decoded['document'];
    }
    final buffer = StringBuffer();
    _walkTiptap(document, buffer);
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
    } else if (type == 'hardBreak') {
      buffer.write('\n');
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

/// Converts a tiptap document JSON string into an HTML fragment, preserving
/// inline marks (bold/italic/underline/link) and rendering embedded
/// `da-deviation` nodes (a journal's inline artwork) as `<img>` elements with
/// a resolved Wix image URL.
String tiptapToHtml(String json) {
  try {
    final decoded = jsonDecode(json);
    Object? document = decoded;
    if (decoded is Map && decoded['document'] is Map) {
      document = decoded['document'];
    }
    final buffer = StringBuffer();
    _walkTiptapHtml(document, buffer);
    return buffer.toString();
  } on Object {
    return '';
  }
}

void _walkTiptapHtml(Object? node, StringBuffer buffer) {
  if (node is Map) {
    final type = node['type'];
    if (type == 'text') {
      final text = node['text'];
      if (text is String) {
        buffer.write(_applyTiptapMarks(_escapeHtml(text), node['marks']));
      }
      return;
    }
    if (type == 'hardBreak') {
      buffer.write('<br>');
      return;
    }
    if (type == 'da-deviation') {
      final attrs = node['attrs'];
      final deviation = attrs is Map ? attrs['deviation'] : null;
      if (deviation is! Map) return;
      final media = deviation['media'];
      final imageUrl = media is Map ? _wixImageUrl(media) : null;
      final devUrl = deviation['url'];
      final title = deviation['title'] as String? ?? '';
      if (imageUrl != null) {
        if (devUrl is String && devUrl.isNotEmpty) {
          buffer.write('<a href="${_escapeHtml(devUrl)}">');
        }
        buffer.write(
          '<img src="${_escapeHtml(imageUrl)}" '
          'style="max-width:100%;height:auto;" />',
        );
        if (devUrl is String && devUrl.isNotEmpty) {
          buffer.write('</a>');
        }
      } else if (devUrl is String && devUrl.isNotEmpty) {
        // A literature/other embed without resampled media: keep it as a link.
        buffer.write(
          '<a href="${_escapeHtml(devUrl)}">📖 ${_escapeHtml(title)}</a>',
        );
      }
      return;
    }
    if (type == 'da-gif') {
      final attrs = node['attrs'];
      final url = attrs is Map ? attrs['url'] as String? : null;
      if (url != null && url.isNotEmpty) {
        buffer.write(
          '<img src="${_escapeHtml(url)}" '
          'style="max-width:100%;height:auto;" />',
        );
      }
      return;
    }
    if (type == 'da-video') {
      final attrs = node['attrs'];
      final src = attrs is Map ? attrs['src'] as String? : null;
      if (src != null && src.isNotEmpty) {
        buffer.write('<a href="${_escapeHtml(src)}">▶</a>');
      }
      return;
    }
    if (type == 'da-mention') {
      final attrs = node['attrs'];
      final user = attrs is Map ? attrs['user'] : null;
      final username = user is Map ? user['username'] as String? : null;
      if (username != null && username.isNotEmpty) {
        buffer.write(
          '<a href="https://www.deviantart.com/'
          '${Uri.encodeComponent(username.toLowerCase())}">'
          '@${_escapeHtml(username)}</a>',
        );
      }
      return;
    }
    if (type == 'image') {
      final attrs = node['attrs'];
      final src = attrs is Map ? attrs['src'] as String? : null;
      if (src != null && src.isNotEmpty) {
        buffer.write(
          '<img src="${_escapeHtml(src)}" '
          'style="max-width:100%;height:auto;" />',
        );
      }
      return;
    }
    if (type == 'horizontalRule') {
      buffer.write('<hr>');
      return;
    }
    final tag = switch (type) {
      'heading' => 'h${_headingLevel(node['attrs'])}',
      'paragraph' => 'p',
      'blockquote' => 'blockquote',
      'bulletList' => 'ul',
      'orderedList' => 'ol',
      'listItem' => 'li',
      _ => null,
    };
    if (tag != null) buffer.write('<$tag>');
    final content = node['content'];
    if (content is List) {
      for (final child in content) {
        _walkTiptapHtml(child, buffer);
      }
    }
    if (tag != null) buffer.write('</$tag>');
  } else if (node is List) {
    for (final child in node) {
      _walkTiptapHtml(child, buffer);
    }
  }
}

String _applyTiptapMarks(String text, Object? marks) {
  if (marks is! List || marks.isEmpty) return text;
  String? href;
  final opens = <String>[];
  final closes = <String>[];
  for (final mark in marks) {
    if (mark is! Map) continue;
    switch (mark['type']) {
      case 'bold':
        opens.add('<b>');
        closes.insert(0, '</b>');
      case 'italic':
        opens.add('<i>');
        closes.insert(0, '</i>');
      case 'underline':
        opens.add('<u>');
        closes.insert(0, '</u>');
      case 'strike':
        opens.add('<s>');
        closes.insert(0, '</s>');
      case 'link':
        final attrs = mark['attrs'];
        href = attrs is Map ? attrs['href'] as String? : null;
    }
  }
  if (href != null && href.isNotEmpty) {
    opens.add('<a href="${_escapeHtml(href)}">');
    closes.insert(0, '</a>');
  }
  return '${opens.join()}$text${closes.join()}';
}

int _headingLevel(Object? attrs) {
  if (attrs is Map) {
    final level = attrs['level'];
    if (level is num) return level.toInt().clamp(1, 6);
  }
  return 2;
}

/// Resolves a Wix media descriptor into a display URL. Journals embed inline
/// artwork per page, so prefer the `preview` transform (typically ~700px) over
/// `fullview`/largest — a 30+ page comic would otherwise force dozens of
/// full-resolution images into memory at once.
String? _wixImageUrl(Map media) {
  final base = media['baseUri'] as String?;
  if (base == null || base.isEmpty) return null;
  final pretty = media['prettyName'] as String? ?? '';
  final tokens = (media['token'] as List? ?? const <Object?>[])
      .whereType<String>()
      .toList(growable: false);
  final types = media['types'] as List? ?? const <Object?>[];

  final best =
      wixTypeNamed(types, 'preview') ??
      wixTypeNamed(types, 'fullview') ??
      wixLargestImageType(types);
  final transform = best?['c'];
  final String url;
  if (transform is String) {
    final separator = transform.startsWith('/') ? '' : '/';
    url = '$base$separator${transform.replaceAll('<prettyName>', pretty)}';
  } else {
    url = base;
  }
  return withWixToken(url, best, tokens);
}

String _escapeHtml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
