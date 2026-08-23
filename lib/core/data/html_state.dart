import 'dart:convert';

/// Decodes a `window.<marker> = JSON.parse("...")` assignment from a
/// DeviantArt server-rendered HTML page without evaluating any embedded script.
///
/// DeviantArt emits `\'` inside double-quoted JavaScript string literals, which
/// is valid JavaScript but invalid JSON, so the literal must first be decoded
/// as a JavaScript string and only then parsed as JSON. This is the shared
/// decoder for every web-scraping fetcher (`__INITIAL_STATE__`,
/// `__RCACHE__`, …).
Map<Object?, Object?> jsonParseAssignment(
  String html, {
  required String marker,
  required String missingMessage,
}) {
  final markerIndex = html.indexOf(marker);
  if (markerIndex < 0) {
    throw FormatException(missingMessage);
  }
  final literalStart = markerIndex + marker.length;
  final decoded = decodeJavaScriptStringLiteral(html, literalStart);
  final state = jsonDecode(decoded);
  if (state is! Map) {
    throw const FormatException('Unexpected DeviantArt initial state.');
  }
  return state;
}

/// Decodes one JavaScript string literal starting at the opening quote in
/// [source]. No code is evaluated: only the literal's own escape sequences are
/// interpreted, which is sufficient for the JSON payloads DeviantArt embeds.
String decodeJavaScriptStringLiteral(String source, int start) {
  if (start >= source.length ||
      (source.codeUnitAt(start) != 0x22 && source.codeUnitAt(start) != 0x27)) {
    throw const FormatException('Missing initial-state string literal.');
  }
  final quote = source.codeUnitAt(start);
  final result = StringBuffer();
  var index = start + 1;
  while (index < source.length) {
    final code = source.codeUnitAt(index++);
    if (code == quote) return result.toString();
    if (code != 0x5c) {
      result.writeCharCode(code);
      continue;
    }
    if (index >= source.length) break;
    final escaped = source.codeUnitAt(index++);
    switch (escaped) {
      case 0x62: // b
        result.writeCharCode(0x08);
      case 0x66: // f
        result.writeCharCode(0x0c);
      case 0x6e: // n
        result.writeCharCode(0x0a);
      case 0x72: // r
        result.writeCharCode(0x0d);
      case 0x74: // t
        result.writeCharCode(0x09);
      case 0x76: // v
        result.writeCharCode(0x0b);
      case 0x0a: // JavaScript line continuation
        break;
      case 0x0d:
        if (index < source.length && source.codeUnitAt(index) == 0x0a) {
          index++;
        }
      case 0x78: // xNN
        result.writeCharCode(_hexEscape(source, index, 2));
        index += 2;
      case 0x75: // uNNNN
        result.writeCharCode(_hexEscape(source, index, 4));
        index += 4;
      default:
        // Includes escaped quote, apostrophe, slash, and backslash. JavaScript
        // also permits identity escapes; preserving the escaped character
        // matches browser string-literal semantics for this data container.
        result.writeCharCode(escaped);
    }
  }
  throw const FormatException('Unterminated initial-state string literal.');
}

int _hexEscape(String source, int start, int length) {
  if (start + length > source.length) {
    throw const FormatException('Truncated initial-state escape.');
  }
  final value = int.tryParse(
    source.substring(start, start + length),
    radix: 16,
  );
  if (value == null) {
    throw const FormatException('Invalid initial-state escape.');
  }
  return value;
}
