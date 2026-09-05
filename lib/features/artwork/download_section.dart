import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import 'download_reason.dart';

/// The user-facing label for a media-availability state.
String availabilityLabel(AppStrings s, MediaAvailability availability) {
  switch (availability) {
    case MediaAvailability.available:
      return s.availabilityAvailable;
    case MediaAvailability.loginRequired:
      return s.availabilityLoginRequired;
    case MediaAvailability.purchaseRequired:
      return s.availabilityPurchaseRequired;
    case MediaAvailability.restricted:
      return s.availabilityRestricted;
    case MediaAvailability.unavailable:
      return s.availabilityUnavailable;
    case MediaAvailability.missing:
      return s.availabilityMissing;
  }
}

/// The user-facing hint for a media-availability state (empty when no extra
/// explanation is needed).
String availabilityHint(AppStrings s, MediaAvailability availability) {
  switch (availability) {
    case MediaAvailability.loginRequired:
      return s.hintLoginRequired;
    case MediaAvailability.purchaseRequired:
      return s.hintPurchaseRequired;
    case MediaAvailability.restricted:
      return s.hintRestricted;
    case MediaAvailability.unavailable:
      return s.hintUnavailable;
    case MediaAvailability.missing:
      return s.hintMissing;
    default:
      return '';
  }
}

/// Formats a byte count for display.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// The download button and availability hints shown on the artwork detail page.
final class DownloadSection extends StatelessWidget {
  const DownloadSection({
    super.key,
    required this.s,
    required this.original,
    required this.downloadable,
    required this.transfer,
    required this.downloading,
    required this.lookupFailed,
    required this.onDownload,
    required this.onRetry,
    required this.onRetryAvailability,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final AppStrings s;
  final MediaAsset original;
  final MediaAsset downloadable;
  final TransferSnapshot? transfer;
  final bool downloading;
  final bool lookupFailed;
  final VoidCallback onDownload;
  final VoidCallback onRetry;
  final VoidCallback onRetryAvailability;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    if (transfer != null) {
      return TransferControls(
        s: s,
        transfer: transfer!,
        onPause: onPause,
        onResume: onResume,
        onCancel: onCancel,
        onRetry: onRetry,
      );
    }

    final availability = original.availability;
    final canDownload = downloadable.canTransfer;
    final usingFallback = !original.canTransfer && downloadable.canTransfer;
    final reason = downloadAvailabilityReason(
      s,
      original,
      lookupFailed: lookupFailed,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${s.originalStatusPrefix}${availabilityLabel(s, availability)}'),
        if (original.byteLength != null)
          Text('${s.sizeLabel}${formatBytes(original.byteLength!)}'),
        if (!original.canTransfer) ...[
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    lookupFailed ? Icons.sync_problem : Icons.info_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          s.downloadUnavailableReason,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(reason),
                        if (usingFallback) ...[
                          const SizedBox(height: 4),
                          Text(s.fallbackDownloadNotice),
                        ],
                        if (lookupFailed) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: onRetryAvailability,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: Text(s.retryDownloadCheck),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 4),
        IconButton(
          tooltip: canDownload
              ? downloading
                    ? s.downloading
                    : usingFallback
                    ? s.downloadImage
                    : s.downloadOriginal
              : reason,
          onPressed: canDownload && !downloading ? onDownload : null,
          icon: downloading
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined),
        ),
      ],
    );
  }
}

/// In-progress transfer controls (pause / resume / cancel).
final class TransferControls extends StatelessWidget {
  const TransferControls({
    super.key,
    required this.s,
    required this.transfer,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onRetry,
  });

  final AppStrings s;
  final TransferSnapshot transfer;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failed =
        transfer.state == TransferState.failed ||
        transfer.state == TransferState.notFound;
    final failureReason = failed ? transferFailureReason(s, transfer) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: transfer.progress),
        const SizedBox(height: 8),
        Text('${(transfer.progress * 100).toStringAsFixed(0)}%'),
        if (failureReason != null) ...[
          const SizedBox(height: 8),
          Text(
            s.downloadFailed(failureReason),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(s.retry),
          ),
        ],
        if (transfer.localPath != null) ...[
          const SizedBox(height: 4),
          Text('${s.savedToPrefix}${transfer.localPath}'),
        ],
        if (!transfer.isFinal) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: transfer.state == TransferState.running
                    ? onPause
                    : null,
                child: Text(s.pause),
              ),
              OutlinedButton(
                onPressed: transfer.state == TransferState.paused
                    ? onResume
                    : null,
                child: Text(s.resume),
              ),
              OutlinedButton(onPressed: onCancel, child: Text(s.cancel)),
            ],
          ),
        ],
      ],
    );
  }
}
