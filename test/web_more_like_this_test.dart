import 'dart:convert';
import 'dart:io';

import 'package:daviewer/core/data/web_more_like_this.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the current streamed related-content cache', () {
    final artworks = WebMoreLikeThisFetcher.parseInitialState(
      _relatedCacheHtml(),
      deviationId: '1371131855',
    );

    expect(artworks.map((artwork) => artwork.id), <String>['10', '11']);
    expect(artworks.first.title, 'Gallery result');
    expect(artworks.first.author.username, 'ArtistOne');
    expect(artworks.first.media, isNotEmpty);
    expect(artworks.last.title, 'Recommended result');
  });

  test('falls back to initial state when streamed cache is partial', () {
    final html =
        '<script>window.__RCACHE__ = JSON.parse("{}");</script>${_fixtureHtml()}';

    final artworks = WebMoreLikeThisFetcher.parseInitialState(
      html,
      deviationId: '1371131855',
    );

    expect(artworks.map((artwork) => artwork.id), <String>['10', '11']);
  });

  test('restores website gallery and recommended entities in order', () {
    final html = _fixtureHtml();

    final artworks = WebMoreLikeThisFetcher.parseInitialState(
      html,
      deviationId: '1371131855',
    );

    expect(artworks.map((artwork) => artwork.id), <String>['10', '11']);
    expect(artworks.first.title, 'Gallery result');
    expect(artworks.first.author.username, 'ArtistOne');
    expect(artworks.first.media, isNotEmpty);
    expect(artworks.last.title, 'Recommended result');
  });

  test('excludes boosted entries and ignores missing normalized entities', () {
    final artworks = WebMoreLikeThisFetcher.parseInitialState(
      _fixtureHtml(),
      deviationId: '1371131855',
    );

    expect(artworks.map((artwork) => artwork.id), isNot(contains('99')));
    expect(artworks, hasLength(2));
  });

  test('missing page metadata is inconclusive instead of a false empty', () {
    expect(
      () => WebMoreLikeThisFetcher.parseInitialState(
        _fixtureHtml(),
        deviationId: '404',
      ),
      throwsFormatException,
    );
  });

  const liveHtmlPath = String.fromEnvironment('DA_MORE_LIKE_THIS_HTML');
  if (liveHtmlPath.isNotEmpty) {
    test('parses the captured Comm - New Jersey website recommendations', () {
      final artworks = WebMoreLikeThisFetcher.parseInitialState(
        File(liveHtmlPath).readAsStringSync(),
        deviationId: '1371131855',
      );

      expect(artworks, isNotEmpty);
      expect(artworks.first.id, '1345854091');
      expect(artworks.first.author.username, 'RabidBunny1');
    });
  }
}

String _relatedCacheHtml() {
  final cache = <String, Object?>{
    'relatedContent': <String, Object?>{
      'relatedContent': <Object?>[
        <String, Object?>{
          'contentType': 'gallery',
          'deviations': <Object?>[
            _deviation(10, 'Gallery result')..['author'] = _author(),
          ],
        },
        <String, Object?>{
          'contentType': 'boosted',
          'deviations': <Object?>[
            _deviation(99, 'Promoted result')..['author'] = _author(),
          ],
        },
        <String, Object?>{
          'contentType': 'recommended',
          'deviations': <Object?>[
            _deviation(11, 'Recommended result')..['author'] = _author(),
            _deviation(10, 'Duplicate result')..['author'] = _author(),
          ],
        },
      ],
    },
  };
  final literal = jsonEncode(jsonEncode(cache));
  return '<html><script>window.__RCACHE__ = JSON.parse($literal);'
      '</script></html>';
}

Map<String, Object?> _author() => <String, Object?>{
  'userId': 1,
  'username': 'ArtistOne',
  'usericon': 'https://a.deviantart.net/avatar.png',
};

String _fixtureHtml() {
  final metadata = jsonEncode(<Object?>[
    <String, Object?>{
      'type': 'relatedContent',
      'blocks': <Object?>[
        <String, Object?>{
          'contentType': 'gallery',
          'deviations': <Object?>[
            <String, Object?>{'deviationid': 10},
            <String, Object?>{'deviationid': 404},
          ],
        },
        <String, Object?>{
          'contentType': 'boosted',
          'deviations': <Object?>[
            <String, Object?>{'deviationid': 99},
          ],
        },
        <String, Object?>{
          'contentType': 'recommended',
          'deviations': <Object?>[
            <String, Object?>{'deviationid': 11},
            <String, Object?>{'deviationid': 10},
          ],
        },
      ],
    },
  ]);
  final state = <String, Object?>{
    '@@HEAD': <String, Object?>{
      // The live page emits escaped apostrophes in its JS literal. Keep one in
      // the fixture so the parser cannot regress to double-jsonDecode.
      'script': "performance.mark('ready')",
    },
    '@@DUPERBROWSE': <String, Object?>{
      'currentBiMetadata': <String, Object?>{'1371131855': metadata},
    },
    '@@entities': <String, Object?>{
      'user': <String, Object?>{
        '1': <String, Object?>{
          'userId': 1,
          'username': 'ArtistOne',
          'usericon': 'https://a.deviantart.net/avatar.png',
        },
      },
      'deviation': <String, Object?>{
        '10': _deviation(10, 'Gallery result'),
        '11': _deviation(11, 'Recommended result'),
        '99': _deviation(99, 'Promoted result'),
      },
    },
  };
  final json = jsonEncode(state);
  final literal = jsonEncode(json).replaceAll("'", r"\'");
  return '<html><script>window.__INITIAL_STATE__ = JSON.parse($literal);'
      '</script></html>';
}

Map<String, Object?> _deviation(int id, String title) => <String, Object?>{
  'deviationId': id,
  'title': title,
  'url': 'https://www.deviantart.com/artistone/art/work-$id',
  'author': 1,
  'publishedTime': '2026-08-20T12:00:00-0700',
  'isMature': false,
  'isDownloadable': false,
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
