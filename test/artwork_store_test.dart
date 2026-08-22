import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/features/artwork/artwork_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Artwork _artwork() => Artwork(
  id: '1',
  title: 'title',
  author: UserProfile(id: 'u', username: 'alice'),
  pageUri: Uri.parse('https://d.test/a'),
  media: const <MediaAsset>[],
  description: 'desc',
  publishedAt: DateTime(2026, 1, 1),
  isMature: true,
  isDownloadable: true,
  isFavourited: false,
  isMultiMedia: true,
  tags: const <String>['a', 'b'],
);

void main() {
  test('setFavourite flips the flag and preserves other fields', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final store = container.read(artworkStoreProvider.notifier);
    store.putAll(<Artwork>[_artwork()]);

    store.setFavourite('1', true);
    final updated = container.read(artworkStoreProvider)['1']!;
    expect(updated.isFavourited, isTrue);
    expect(updated.id, '1');
    expect(updated.title, 'title');
    expect(updated.author.username, 'alice');
    expect(updated.description, 'desc');
    expect(updated.isMature, isTrue);
    expect(updated.isDownloadable, isTrue);
    expect(updated.isMultiMedia, isTrue);
    expect(updated.tags, <String>['a', 'b']);

    store.setFavourite('1', false);
    expect(container.read(artworkStoreProvider)['1']!.isFavourited, isFalse);
  });

  test('setFavourite is a no-op for an unknown id', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(artworkStoreProvider.notifier).setFavourite('nope', true);
    expect(container.read(artworkStoreProvider), isEmpty);
  });
}
