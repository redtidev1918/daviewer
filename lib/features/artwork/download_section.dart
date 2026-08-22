import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';

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
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  final AppStrings s;
  final MediaAsset original;
  final MediaAsset downloadable;
  final TransferSnapshot? transfer;
  final bool downloading;
  final VoidCallback onDownload;
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
      );
    }

    final availability = original.availability;
    final canDownload = downloadable.canTransfer;
    final usingFallback = !original.canTransfer && downloadable.canTransfer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('${s.originalStatusPrefix}${availabilityLabel(s, availability)}'),
        if (original.byteLength != null)
          Text('${s.sizeLabel}${formatBytes(original.byteLength!)}'),
        if (usingFallback) ...[
          const SizedBox(height: 4),
          Text(
            s.fallbackDownloadNotice,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: canDownload && !downloading ? onDownload : null,
          icon: downloading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(
            downloading
                ? s.downloading
                : usingFallback
                ? s.downloadImage
                : s.downloadOriginal,
          ),
        ),
        if (!canDownload) ...[
          const SizedBox(height: 8),
          Text(
            availabilityHint(s, availability),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
  });

  final AppStrings s;
  final TransferSnapshot transfer;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LinearProgressIndicator(value: transfer.progress),
        const SizedBox(height: 8),
        Text('${(transfer.progress * 100).toStringAsFixed(0)}%'),
        if (transfer.localPath != null) ...[
          const SizedBox(height: 4),
          Text('${s.savedToPrefix}${transfer.localPath}'),
        ],
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
            OutlinedButton(
              onPressed: transfer.state == TransferState.completed
                  ? null
                  : onCancel,
              child: Text(s.cancel),
            ),
          ],
        ),
      ],
    );
  }
}
