/// Helpers for the downloads feature. Pure and side-effect free.
library;

import 'dart:convert';

/// Creates a stable task id for one image without putting provider ids directly
/// into the platform download database.
String imageTransferId(String artworkId, String assetId) {
  final token = base64Url.encode(utf8.encode(assetId)).replaceAll('=', '');
  return 'artwork-$artworkId-image-$token';
}

/// Recovers the artwork id from an original or numbered image transfer id.
/// Returns `null` when the id does not follow that scheme.
String? artworkIdFromTransfer(String transferId) {
  return RegExp(r'^artwork-(.+)-(?:original|image-[A-Za-z0-9_-]+)$')
      .firstMatch(transferId)
      ?.group(1);
}

/// Whether [path] points to an image file (by extension).
bool isImageFile(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp');
}
