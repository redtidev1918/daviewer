import 'package:daviewer/core/data/web_gallery_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a gallection/search payload with a numeric offset', () {
    final page = WebGallerySearchFetcher.parseJson(<String, Object?>{
      'estTotal': 42,
      'hasMore': true,
      'nextOffset': 24,
      'results': <Object?>[_deviation(10, 'Underwater'), _deviation(11, 'Ink')],
    });

    expect(page.hasMore, isTrue);
    expect(page.nextCursor, '24');
    expect(page.items.map((artwork) => artwork.id), <String>['10', '11']);
    expect(page.items.first.title, 'Underwater');
    expect(page.items.first.author.username, 'ArtistOne');
    expect(page.items.first.media, isNotEmpty);
  });

  test('hasMore is false when the payload reports the last page', () {
    final page = WebGallerySearchFetcher.parseJson(<String, Object?>{
      'hasMore': false,
      'results': <Object?>[_deviation(20, 'Last')],
    });

    expect(page.hasMore, isFalse);
    expect(page.nextCursor, isNull);
  });

  test('throws FormatException when results are missing', () {
    expect(
      () => WebGallerySearchFetcher.parseJson(<String, Object?>{'hasMore': false}),
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
