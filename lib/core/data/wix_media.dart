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

/// Resolves a resampled image URL for a Wix descriptor: `baseUri` + the
/// transform of the type whose width is closest to [targetWidth] (the largest
/// when [targetWidth] is null), with `<prettyName>` substituted and the signed
/// token appended. Falls back to the raw [base] (with token) when no resampled
/// type is present, and to null when [base] is missing.
Uri? wixResampledUrl(
  String? base,
  String pretty,
  List<String> tokens,
  List<Object?> types, {
  int? targetWidth,
}) {
  if (base == null || base.isEmpty) return null;
  Map<Object?, Object?>? best;
  var bestScore = 1 << 30;
  for (final type in types) {
    if (type is! Map) continue;
    final transform = type['c'];
    if (transform is! String || transform.isEmpty) continue;
    final width = (type['w'] as num?)?.toInt() ?? 0;
    final score = targetWidth == null ? -width : (width - targetWidth).abs();
    if (score < bestScore) {
      bestScore = score;
      best = type;
    }
  }
  if (best == null) {
    return Uri.tryParse(withWixToken(base, null, tokens));
  }
  final transform = (best['c'] as String).replaceAll('<prettyName>', pretty);
  return Uri.tryParse(withWixToken('$base$transform', best, tokens));
}
