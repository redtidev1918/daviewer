import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/feed/artwork_feed_controller.dart';
import 'package:daviewer/shared/widgets/artwork_feed_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('feature copy hides provider parsing details', (tester) async {
    const rawMessage = 'The official API page does not contain a results list.';
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ArtworkFeedGrid(
              feed: ArtworkFeedState(
                error: DAKitException(
                  kind: DAKitFailureKind.parsing,
                  code: 'api.page.missing_results',
                  message: rawMessage,
                ),
              ),
              emptyMessage: 'Empty',
              errorMessage: 'Watched feed is temporarily unavailable.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Watched feed is temporarily unavailable.'), findsOne);
    expect(find.text(rawMessage), findsNothing);
  });
}
