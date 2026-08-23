import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/features/artwork/artwork_detail_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Artwork _artwork(String id, {List<String> tags = const <String>[]}) => Artwork(
  id: id,
  title: 'Artwork $id',
  author: UserProfile(id: 'user', username: 'artist'),
  pageUri: Uri.parse('https://example.test/art/$id'),
  media: const <MediaAsset>[],
  tags: tags,
);

void main() {
  test('complete feed tags avoid an unnecessary detail request', () async {
    var fetches = 0;
    final tags = await resolveOfficialArtworkTags(
      _artwork('a', tags: const <String>['cat']),
      fetchDetail: () async {
        fetches++;
        return _artwork('a', tags: const <String>['unused']);
      },
    );

    expect(tags, const <String>['cat']);
    expect(fetches, 0);
  });

  test('empty watched-feed tags hydrate from the artwork detail', () async {
    var fetches = 0;
    final tags = await resolveOfficialArtworkTags(
      _artwork('watched-id'),
      fetchDetail: () async {
        fetches++;
        return _artwork(
          'watched-id',
          tags: const <String>['portrait', 'digitalart'],
        );
      },
    );

    expect(tags, const <String>['portrait', 'digitalart']);
    expect(fetches, 1);
  });

  test('tag hydration failure leaves the detail page usable', () async {
    final tags = await resolveOfficialArtworkTags(
      _artwork('watched-id'),
      fetchDetail: () => Future<Artwork>.error(StateError('offline')),
    );

    expect(tags, isEmpty);
  });
}
