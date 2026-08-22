import 'package:cached_network_image/cached_network_image.dart';
import 'package:daviewer/core/l10n/app_strings.dart';
import 'package:daviewer/features/artwork/rich_html.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes provider-relative rich image URLs', () {
    expect(
      normalizeRichImageUrl('//images.example.test/a.jpg'),
      'https://images.example.test/a.jpg',
    );
    expect(
      normalizeRichImageUrl('/assets/a.jpg'),
      'https://www.deviantart.com/assets/a.jpg',
    );
  });

  testWidgets('rich network images use the shared disk cache renderer', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: RichHtml(
            data: '<p>before</p><img src="https://example.test/a.jpg">',
            strings: AppStrings.en,
            onLinkTap: _ignoreLink,
          ),
        ),
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('before'), findsOneWidget);
  });
}

void _ignoreLink(String? url) {}
