import 'dart:convert';

import 'package:daviewer/shared/widgets/full_screen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final bytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  );

  testWidgets('shared image viewer pins the zoom interaction contract', (
    tester,
  ) async {
    var artworkNavigation = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: FullScreenImageViewer(
            imageProvider: MemoryImage(bytes),
            onNextArtwork: () => artworkNavigation++,
          ),
        ),
      ),
    );

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 8);
    expect(viewer.panEnabled, isFalse);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);

    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pump();
    expect(find.byIcon(Icons.zoom_out_map), findsOneWidget);
    expect(
      tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .panEnabled,
      isTrue,
    );

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final before = controller.value.getTranslation();
    await tester.drag(find.byType(InteractiveViewer), const Offset(80, 40));
    await tester.pump();
    final after = controller.value.getTranslation();

    expect(after.x, isNot(before.x));
    expect(after.y, isNot(before.y));
    expect(artworkNavigation, 0);
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('full-screen swipe changes artwork only at base zoom', (
    tester,
  ) async {
    var next = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => FullScreenImageViewer(
                    imageProvider: MemoryImage(bytes),
                    onNextArtwork: () => next++,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(find.byType(InteractiveViewer), const Offset(-180, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(next, 1);
    expect(find.text('open'), findsOneWidget);
  });
}
