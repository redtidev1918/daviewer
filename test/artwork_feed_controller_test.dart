import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/feed/artwork_feed_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final user = UserProfile(id: 'user-1', username: 'sample');
  Artwork artwork(int index) => Artwork(
    id: 'art-$index',
    title: 'Art $index',
    author: user,
    pageUri: Uri.parse('https://example.test/art-$index'),
    media: const <MediaAsset>[],
  );

  test('loads and appends pages from cursor', () async {
    var calls = 0;
    final controller = ArtworkFeedController((request) async {
      calls += 1;
      if (request.cursor == null) {
        return Page<Artwork>(
          items: <Artwork>[artwork(1), artwork(2)],
          hasMore: true,
          nextCursor: 'next',
        );
      }
      return Page<Artwork>(items: <Artwork>[artwork(3)], hasMore: false);
    });

    await controller.refresh();
    expect(controller.state.items, hasLength(2));
    expect(controller.state.hasMore, isTrue);

    await controller.loadMore();
    expect(controller.state.items, hasLength(3));
    expect(controller.state.hasMore, isFalse);
    expect(calls, 2);
  });
}
