/// Helpers for the downloads feature. Pure and side-effect free.
library;

/// Recovers the artwork id from a transfer id of the form
/// `artwork-<id>-original` (the scheme used by the artwork detail download).
/// Returns `null` when the id does not follow that scheme.
String? artworkIdFromTransfer(String transferId) {
  const prefix = 'artwork-';
  const suffix = '-original';
  if (!transferId.startsWith(prefix) || !transferId.endsWith(suffix)) {
    return null;
  }
  final id = transferId.substring(
    prefix.length,
    transferId.length - suffix.length,
  );
  return id.isEmpty ? null : id;
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
