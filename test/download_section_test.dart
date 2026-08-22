import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/core/l10n/app_strings.dart';
import 'package:daviewer/features/artwork/download_section.dart';
import 'package:daviewer/features/artwork/download_reason.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  const en = AppStrings.en;
  const zh = AppStrings.zh;

  test('availabilityLabel maps each state', () {
    expect(availabilityLabel(en, MediaAvailability.available), 'Available');
    expect(availabilityLabel(en, MediaAvailability.unavailable), 'Unavailable');
    expect(
      availabilityLabel(en, MediaAvailability.missing),
      'Deleted or unavailable',
    );
    expect(availabilityLabel(zh, MediaAvailability.available), '可下载');
  });

  test('availabilityHint is empty only for available state', () {
    expect(availabilityHint(en, MediaAvailability.available), isEmpty);
    expect(availabilityHint(en, MediaAvailability.missing), isNotEmpty);
  });

  test('availabilityHint is non-empty for restricted states', () {
    expect(availabilityHint(en, MediaAvailability.loginRequired), isNotEmpty);
    expect(
      availabilityHint(en, MediaAvailability.purchaseRequired),
      isNotEmpty,
    );
    expect(availabilityHint(en, MediaAvailability.restricted), isNotEmpty);
    expect(availabilityHint(en, MediaAvailability.unavailable), isNotEmpty);
  });

  test('formatBytes formats B, KB, and MB', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(3 * 1024 * 1024), '3.0 MB');
  });

  test('provider free-limit and creator-disabled reasons are localized', () {
    const limit = MediaAsset(
      id: 'limit',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.unavailable,
      availabilityReason: 'Free download limit reached.',
    );
    const disabled = MediaAsset(
      id: 'disabled',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.unavailable,
      availabilityReason: 'Deviation not downloadable.',
    );

    expect(downloadAvailabilityReason(zh, limit), zh.downloadLimitReached);
    expect(
      downloadAvailabilityReason(zh, disabled),
      zh.creatorDisabledDownload,
    );
  });

  test('unknown provider reason is retained instead of discarded', () {
    const asset = MediaAsset(
      id: 'restricted',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.restricted,
      availabilityReason: 'Region restriction.',
    );

    expect(
      downloadAvailabilityReason(en, asset),
      'DeviantArt says: Region restriction.',
    );
  });

  test('transient lookup failure is distinct from a definitive denial', () {
    const asset = MediaAsset(
      id: 'unknown',
      kind: MediaKind.unknown,
      role: MediaRole.original,
      availability: MediaAvailability.unavailable,
    );

    expect(
      downloadAvailabilityReason(en, asset, lookupFailed: true),
      en.downloadAvailabilityCheckFailed,
    );
    expect(downloadAvailabilityReason(en, asset), en.hintUnavailable);
  });

  test('fallback chooses the largest image but never a video poster', () {
    final small = MediaAsset(
      id: 'small',
      kind: MediaKind.image,
      role: MediaRole.preview,
      availability: MediaAvailability.available,
      uri: Uri.parse('https://example.test/small.jpg'),
      width: 400,
      height: 300,
    );
    final large = MediaAsset(
      id: 'large',
      kind: MediaKind.image,
      role: MediaRole.preview,
      availability: MediaAvailability.available,
      uri: Uri.parse('https://example.test/large.jpg'),
      width: 1600,
      height: 1200,
    );
    final video = MediaAsset(
      id: 'video',
      kind: MediaKind.video,
      role: MediaRole.preview,
      availability: MediaAvailability.available,
      uri: Uri.parse('https://example.test/video.mp4'),
    );

    expect(bestFallbackImage(<MediaAsset>[small, large]), same(large));
    expect(bestFallbackImage(<MediaAsset>[small, video]), isNull);
  });

  test(
    'background failure reasons classify permission and not-found errors',
    () {
      const forbidden = TransferSnapshot(
        id: 'forbidden',
        state: TransferState.failed,
        progress: 0,
        failureCode: 'httpResponse',
        failureMessage: 'HTTP 403 Forbidden',
      );
      const missing = TransferSnapshot(
        id: 'missing',
        state: TransferState.notFound,
        progress: 0,
      );

      expect(
        transferFailureReason(zh, forbidden),
        zh.downloadFailurePermission,
      );
      expect(transferFailureReason(zh, missing), zh.downloadFailureNotFound);
    },
  );

  testWidgets('disabled download always shows a visible reason', (
    tester,
  ) async {
    const original = MediaAsset(
      id: 'blocked',
      kind: MediaKind.image,
      role: MediaRole.original,
      availability: MediaAvailability.purchaseRequired,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DownloadSection(
            s: zh,
            original: original,
            downloadable: original,
            transfer: null,
            downloading: false,
            lookupFailed: false,
            onDownload: () {},
            onRetry: () {},
            onRetryAvailability: () {},
            onPause: () {},
            onResume: () {},
            onCancel: () {},
          ),
        ),
      ),
    );

    expect(find.text(zh.downloadUnavailableReason), findsOneWidget);
    expect(find.text(zh.hintPurchaseRequired), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
