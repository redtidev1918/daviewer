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
    final result = await resolveOfficialArtworkTags(
      _artwork('a', tags: const <String>['cat']),
      fetchTags: () async {
        fetches++;
        return const <String>['unused'];
      },
    );

    expect(result.tags, const <String>['cat']);
    expect(result.isConfirmed, isTrue);
    expect(fetches, 0);
  });

  test('empty watched-feed tags hydrate from deviation metadata', () async {
    var fetches = 0;
    final result = await resolveOfficialArtworkTags(
      _artwork('watched-id'),
      fetchTags: () async {
        fetches++;
        return const <String>['portrait', 'digitalart'];
      },
    );

    expect(result.tags, const <String>['portrait', 'digitalart']);
    expect(result.isConfirmed, isTrue);
    expect(fetches, 1);
  });

  test('confirmed tagless artwork avoids repeated detail requests', () async {
    var fetches = 0;
    final result = await resolveOfficialArtworkTags(
      _artwork('tagless'),
      alreadyResolved: true,
      fetchTags: () async {
        fetches++;
        return const <String>[];
      },
    );

    expect(result.tags, isEmpty);
    expect(result.isConfirmed, isTrue);
    expect(fetches, 0);
  });

  test('tag hydration failure leaves the detail page usable', () async {
    final result = await resolveOfficialArtworkTags(
      _artwork('watched-id'),
      fetchTags: () => Future<List<String>>.error(StateError('offline')),
    );

    expect(result.tags, isEmpty);
    expect(result.isConfirmed, isFalse);
  });
}
