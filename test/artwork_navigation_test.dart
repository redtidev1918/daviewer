import 'package:daviewer/features/artwork/artwork_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('browse session deduplicates and resolves both neighbours', () {
    final session = ArtworkBrowseSession(<String>['a', 'b', 'b', '', 'c']);

    expect(session.ids, <String>['a', 'b', 'c']);
    expect(session.previousOf('a'), isNull);
    expect(session.previousOf('b'), 'a');
    expect(session.nextOf('b'), 'c');
    expect(session.nextOf('c'), isNull);
    expect(session.nextOf('missing'), isNull);
  });

  test('multi-image edge tracker ignores ordinary page movement', () {
    final tracker = ArtworkEdgeSwipeTracker();

    tracker.add(80, atFirst: false, atLast: false);
    expect(tracker.finish(), isNull);
  });

  test('multi-image edge tracker changes artwork only past an edge', () {
    final tracker = ArtworkEdgeSwipeTracker();

    tracker.add(-30, atFirst: true, atLast: false);
    tracker.add(-30, atFirst: true, atLast: false);
    expect(tracker.finish(), ArtworkSwipeDirection.previous);

    tracker.add(60, atFirst: false, atLast: true);
    expect(tracker.finish(), ArtworkSwipeDirection.next);
  });

  testWidgets('swipe region maps left and right drags to neighbours', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ArtworkSwipeRegion(
            onPrevious: () => previous++,
            onNext: () => next++,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(ArtworkSwipeRegion), const Offset(-160, 0));
    await tester.pump();
    expect(next, 1);

    await tester.drag(find.byType(ArtworkSwipeRegion), const Offset(160, 0));
    await tester.pump();
    expect(previous, 1);
  });
}
