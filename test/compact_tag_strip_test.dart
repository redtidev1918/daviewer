import 'package:daviewer/shared/widgets/compact_tag_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tag strip stays one compact row and keeps every tag', (
    tester,
  ) async {
    String? selected;
    final tags = List<String>.generate(20, (index) => 'long-tag-$index');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CompactTagStrip(
            tags: tags,
            onSelected: (tag) => selected = tag,
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(CompactTagStrip)).height, 34);
    expect(find.text('#long-tag-0'), findsOneWidget);
    expect(find.byType(Wrap), findsNothing);

    await tester.tap(find.text('#long-tag-0'));
    expect(selected, 'long-tag-0');
  });
}
