/// Helpers for resolving DeviantArt's Wix media descriptors (`baseUri` +
/// `prettyName` + `token[]` + `types[]`) into usable URLs. DeviantArt serves
/// images through Wix/WixMP with resampled "types" (transforms) and signed
/// tokens; this module is the single source of truth for that logic (DRY).
library;

/// Appends the signed access token to [url], preferring the token referenced
/// by [type]'s `r` index and falling back to the first token. Returns [url]
/// unchanged when no token is available.
String withWixToken(
  String url,
  Map<Object?, Object?>? type,
  List<String> tokens,
) {
  if (tokens.isEmpty) return url;
  final index = type?['r'];
  final token = index is int && index >= 0 && index < tokens.length
      ? tokens[index]
      : tokens.first;
  if (token.isEmpty) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url${separator}token=$token';
}

/// Returns the type named [name] (e.g. `fullview` or `preview`), if present.
Map<Object?, Object?>? wixTypeNamed(List<Object?> types, String name) {
  for (final type in types) {
    if (type is Map && type['t'] == name) return type;
  }
  return null;
}

/// The largest resampled image type — the one with the biggest `w` and a `c`
/// transform.
Map<Object?, Object?>? wixLargestImageType(List<Object?> types) {
  Map<Object?, Object?>? best;
  var bestWidth = -1;
  for (final type in types) {
    if (type is! Map) continue;
    final transform = type['c'];
    if (transform is! String || transform.isEmpty) continue;
    final width = (type['w'] as num?)?.toInt() ?? 0;
    if (width > bestWidth) {
      bestWidth = width;
      best = type;
    }
  }
  return best;
}
