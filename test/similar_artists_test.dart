import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/features/artwork/artwork_detail_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives unique similar artists, excluding the seed author', () {
    final artists = similarArtistsFrom(
      seedAuthor: _artist('seed'),
      related: <Artwork>[
        _artwork('a', 'alice'),
        _artwork('b', 'bob'),
        _artwork('c', 'alice'), // duplicate author
        _artwork('d', 'seed'), // seed author must be excluded
        _artwork('e', ''), // empty username ignored
      ],
    );

    expect(artists.map((artist) => artist.username), <String>['alice', 'bob']);
  });

  test('returns an empty list when there is no other author', () {
    final artists = similarArtistsFrom(
      seedAuthor: _artist('seed'),
      related: <Artwork>[_artwork('a', 'seed')],
    );

    expect(artists, isEmpty);
  });
}

UserProfile _artist(String username) =>
    UserProfile(id: 'id-$username', username: username);

Artwork _artwork(String id, String authorUsername) => Artwork(
  id: id,
  title: 'work $id',
  author: _artist(authorUsername),
  pageUri: Uri.parse('https://www.deviantart.com/$authorUsername/art/$id'),
  media: const <MediaAsset>[],
);
