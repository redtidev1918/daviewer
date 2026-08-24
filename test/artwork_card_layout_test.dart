import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/shared/widgets/artwork_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Artwork _bannerArtwork() => Artwork(
  id: 'banner',
  title: 'A very wide artwork title',
  author: const UserProfile(id: 'artist-id', username: 'artist'),
  pageUri: Uri.parse('https://example.test/art/banner'),
  media: const <MediaAsset>[
    MediaAsset(
      id: 'preview',
      kind: MediaKind.image,
      role: MediaRole.preview,
      availability: MediaAvailability.available,
      width: 3000,
      height: 1000,
    ),
  ],
);

void main() {
  testWidgets('mobile banner previews keep more visual height', (tester) async {
    late double ratio;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Builder(
            builder: (context) {
              ratio = artworkPreviewAspectRatio(context, _bannerArtwork());
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    expect(ratio, 1.6);
  });

  testWidgets('short banner cards use one compact metadata row', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 105,
              child: ArtworkCard(artwork: _bannerArtwork()),
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('A very wide artwork title'));
    expect(title.maxLines, 1);
    expect(find.text('@artist'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsNothing);
  });

  testWidgets('tall cards retain the richer metadata layout', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 240,
              child: ArtworkCard(artwork: _bannerArtwork()),
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('A very wide artwork title'));
    expect(title.maxLines, 2);
    expect(find.text('artist'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
