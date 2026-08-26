import 'package:daviewer/core/data/web_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a search/deviations payload with a server cursor', () {
    final page = WebSearchFetcher.parseJson(<String, Object?>{
      'hasMore': true,
      'nextCursor': 'abc123',
      'deviations': <Object?>[_deviation(10, 'Work 10')],
    });

    expect(page.hasMore, isTrue);
    expect(page.nextCursor, 'abc123');
    expect(page.items.map((artwork) => artwork.id), <String>['10']);
    expect(page.items.first.title, 'Work 10');
    expect(page.items.first.author.username, 'ArtistOne');
    expect(page.items.first.media, isNotEmpty);
  });

  test('falls back to a numeric nextOffset continuation', () {
    final page = WebSearchFetcher.parseJson(<String, Object?>{
      'hasMore': true,
      'nextOffset': 24,
      'deviations': <Object?>[_deviation(11, 'Work 11')],
    });

    expect(page.hasMore, isTrue);
    expect(page.nextCursor, '24');
  });

  test('hasMore is false when the payload reports the last page', () {
    final page = WebSearchFetcher.parseJson(<String, Object?>{
      'hasMore': false,
      'deviations': <Object?>[_deviation(20, 'Work 20')],
    });

    expect(page.hasMore, isFalse);
    expect(page.nextCursor, isNull);
  });

  test('throws FormatException when deviations are missing', () {
    expect(
      () => WebSearchFetcher.parseJson(<String, Object?>{'hasMore': false}),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _deviation(int id, String title) => <String, Object?>{
  'deviationId': id,
  'title': title,
  'type': 'image',
  'url': 'https://www.deviantart.com/artistone/art/work-$id',
  'author': <String, Object?>{
    'userId': 1,
    'username': 'ArtistOne',
    'usericon': 'https://a.deviantart.net/avatar.png',
  },
  'publishedTime': '2026-08-20T12:00:00-0700',
  'isMature': false,
  'isDownloadable': false,
  'isFavourited': false,
  'isMultiMedia': false,
  'media': <String, Object?>{
    'baseUri': 'https://images.example.test/work-$id.jpg',
    'prettyName': 'work_$id',
    'token': <String>[],
    'types': <Object?>[
      <String, Object?>{
        't': '300W',
        'c': '/v1/fit/w_300,h_300/work-$id.jpg',
        'w': 300,
        'h': 200,
      },
    ],
  },
};
