import 'package:daviewer/core/data/rfy_feed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a personalized rfy/deviations payload', () {
    final page = RfyFeedFetcher.parseJson(<String, Object?>{
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

  test('hasMore is false when nextCursor is absent', () {
    final page = RfyFeedFetcher.parseJson(<String, Object?>{
      'deviations': <Object?>[_deviation(20, 'Work 20')],
    });

    expect(page.hasMore, isFalse);
    expect(page.nextCursor, isNull);
  });

  test('throws FormatException when deviations are missing', () {
    expect(
      () => RfyFeedFetcher.parseJson(<String, Object?>{'nextCursor': 'x'}),
      throwsFormatException,
    );
  });

  test('uses the update time for feed ordering when present', () {
    final page = RfyFeedFetcher.parseJson(<String, Object?>{
      'deviations': <Object?>[
        <String, Object?>{
          ..._deviation(30, 'Edited work'),
          'publishedTime': '2026-08-01T10:00:00-0700',
          'updatedTime': '2026-08-25T15:30:00-0700',
        },
      ],
    });

    // The model's single timestamp carries the latest activity time so feed
    // ordering reflects edits; the init payload still exposes both dates to
    // the detail page.
    expect(
      page.items.single.publishedAt?.toUtc(),
      DateTime.parse('2026-08-25T22:30:00Z'),
    );
  });

  test('falls back to publish time when no update time exists', () {
    final page = RfyFeedFetcher.parseJson(<String, Object?>{
      'deviations': <Object?>[_deviation(40, 'Fresh work')],
    });

    expect(
      page.items.single.publishedAt?.toUtc(),
      DateTime.parse('2026-08-20T19:00:00Z'),
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
