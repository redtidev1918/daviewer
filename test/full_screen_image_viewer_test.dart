import 'dart:convert';

import 'package:daviewer/shared/widgets/full_screen_image_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shared image viewer pins the zoom interaction contract', (
    tester,
  ) async {
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      'YAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: FullScreenImageViewer(imageProvider: MemoryImage(bytes)),
        ),
      ),
    );

    final viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 8);
    expect(find.byIcon(Icons.zoom_in), findsOneWidget);

    await tester.tap(find.byIcon(Icons.zoom_in));
    await tester.pump();
    expect(find.byIcon(Icons.zoom_out_map), findsOneWidget);
  });
}
