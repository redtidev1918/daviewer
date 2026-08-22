import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/core/l10n/app_strings.dart';
import 'package:daviewer/features/artwork/download_section.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('availabilityHint is empty for non-hint states', () {
    expect(availabilityHint(en, MediaAvailability.available), isEmpty);
    expect(availabilityHint(en, MediaAvailability.missing), isEmpty);
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
}
