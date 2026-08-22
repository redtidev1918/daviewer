import 'package:dakit_flutter/dakit_flutter.dart';

import '../../core/l10n/app_strings.dart';

/// Picks the highest-resolution downloadable image that is actually displayed
/// by the artwork. Video posters are deliberately excluded: a bright download
/// button must never imply that a restricted video itself can be downloaded.
MediaAsset? bestFallbackImage(List<MediaAsset> media) {
  if (media.any((asset) => asset.kind == MediaKind.video)) return null;
  final candidates = media
      .where(
        (asset) =>
            asset.kind == MediaKind.image &&
            asset.role != MediaRole.original &&
            asset.canTransfer,
      )
      .toList();
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => _imageArea(b).compareTo(_imageArea(a)));
  return candidates.first;
}

int _imageArea(MediaAsset asset) => (asset.width ?? 0) * (asset.height ?? 0);

/// Converts both typed availability and provider-specific detail into a clear,
/// localized explanation. Known provider phrases are localized; unknown text
/// is still retained so useful upstream information is never discarded.
String downloadAvailabilityReason(
  AppStrings s,
  MediaAsset asset, {
  bool lookupFailed = false,
}) {
  if (lookupFailed) return s.downloadAvailabilityCheckFailed;
  final providerReason = asset.availabilityReason?.trim();
  if (providerReason != null && providerReason.isNotEmpty) {
    final normalized = providerReason.toLowerCase();
    if (normalized.contains('free') && normalized.contains('limit')) {
      return s.downloadLimitReached;
    }
    if (normalized.contains('not downloadable') ||
        normalized.contains('download is disabled')) {
      return s.creatorDisabledDownload;
    }
    return s.providerDownloadReason(providerReason);
  }
  return switch (asset.availability) {
    MediaAvailability.loginRequired => s.hintLoginRequired,
    MediaAvailability.purchaseRequired => s.hintPurchaseRequired,
    MediaAvailability.restricted => s.hintRestricted,
    MediaAvailability.unavailable => s.hintUnavailable,
    MediaAvailability.missing => s.hintMissing,
    MediaAvailability.available => '',
  };
}

/// A stable explanation for background-transfer failures. Native backends
/// differ in wording, so classify by both code and message, then preserve an
/// unknown backend message as the final fallback.
String transferFailureReason(AppStrings s, TransferSnapshot snapshot) {
  if (snapshot.state == TransferState.notFound) {
    return s.downloadFailureNotFound;
  }
  final code = (snapshot.failureCode ?? '').toLowerCase();
  final message = (snapshot.failureMessage ?? '').trim();
  final normalized = '$code ${message.toLowerCase()}';
  if (normalized.contains('401') ||
      normalized.contains('403') ||
      normalized.contains('unauthor') ||
      normalized.contains('forbidden') ||
      normalized.contains('permission')) {
    return s.downloadFailurePermission;
  }
  if (normalized.contains('404') ||
      normalized.contains('not found') ||
      normalized.contains('expired')) {
    return s.downloadFailureNotFound;
  }
  if (normalized.contains('storage') ||
      normalized.contains('file system') ||
      normalized.contains('disk') ||
      normalized.contains('space')) {
    return s.downloadFailureStorage;
  }
  if (normalized.contains('network') ||
      normalized.contains('connection') ||
      normalized.contains('timeout') ||
      normalized.contains('socket') ||
      normalized.contains('host')) {
    return s.downloadFailureNetwork;
  }
  return message.isEmpty ? s.hintUnavailable : message;
}

String immediateDownloadFailureReason(AppStrings s, Object error) {
  final failure = error is DAKitException ? error : null;
  return transferFailureReason(
    s,
    TransferSnapshot(
      id: 'immediate-failure',
      state: failure?.kind == DAKitFailureKind.notFound
          ? TransferState.notFound
          : TransferState.failed,
      progress: 0,
      failureCode: failure?.code,
      failureMessage: failure?.message ?? '$error',
    ),
  );
}
