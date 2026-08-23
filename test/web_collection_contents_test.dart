import 'dart:convert';
import 'dart:io';

import 'package:daviewer/core/data/web_collection_contents.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts a folder page deviations and hasMore flag', () {
    final page = WebCollectionContentsFetcher.parsePage(
      _fixtureHtml(hasMore: true, ids: <int>[10, 11]),
    );

    expect(page.hasMore, isTrue);
    expect(page.items.map((artwork) => artwork.id), <String>['10', '11']);
    expect(page.items.first.title, 'Artwork 10');
    expect(page.items.first.author.username, 'ArtistOne');
    expect(page.items.first.media, isNotEmpty);
  });

  test('reports hasMore false on the last page', () {
    final page = WebCollectionContentsFetcher.parsePage(
      _fixtureHtml(hasMore: false, ids: <int>[20]),
    );

    expect(page.hasMore, isFalse);
    expect(page.items, hasLength(1));
  });

  test('skips media-less entries (journals)', () {
    final page = WebCollectionContentsFetcher.parsePage(
      _fixtureHtml(
        hasMore: false,
        deviations: <Map<String, Object?>>[
          _deviation(30, 'A journal', withMedia: false),
          _deviation(31, 'An image'),
        ],
      ),
    );

    expect(page.items.map((artwork) => artwork.id), <String>['31']);
  });

  test('throws FormatException when folder deviations are missing', () {
    expect(
      () => WebCollectionContentsFetcher.parsePage('<html></html>'),
      throwsFormatException,
    );
  });

  const liveHtmlPath = String.fromEnvironment('DA_COLLECTION_HTML');
  if (liveHtmlPath.isNotEmpty) {
    test('parses a captured live favourites folder page', () {
      final page = WebCollectionContentsFetcher.parsePage(
        File(liveHtmlPath).readAsStringSync(),
      );

      expect(page.items, isNotEmpty);
      expect(page.items.first.id, '819241297');
      expect(page.items.first.title, 'Purple sad');
      expect(page.items.first.author.username, 'elsevilla');
    });
  }
}

String _fixtureHtml({
  required bool hasMore,
  List<int>? ids,
  List<Map<String, Object?>>? deviations,
}) {
  final items =
      deviations ??
      <Map<String, Object?>>[
        for (final id in ids ?? const <int>[10]) _deviation(id, 'Artwork $id'),
      ];
  final state = <String, Object?>{
    '@@HEAD': <String, Object?>{
      // The live page emits escaped apostrophes in its JS literal. Keep one in
      // the fixture so the parser cannot regress to double-jsonDecode.
      'script': "performance.mark('ready')",
    },
    '@@gruser': <String, Object?>{
      'grusers': <String, Object?>{
        '414281-4-null': <String, Object?>{
          'modules': <String, Object?>{
            '-424439': <String, Object?>{
              'moduleData': <String, Object?>{
                'folderDeviations': <String, Object?>{
                  'username': 'loish',
                  'folderId': 1161139,
                  'hasMore': hasMore,
                  'nextOffset': items.length,
                  'totalPageCount': 1,
                  'deviations': items,
                },
              },
            },
          },
        },
      },
    },
  };
  final json = jsonEncode(state);
  final literal = jsonEncode(json).replaceAll("'", r"\'");
  return '<html><script>window.__INITIAL_STATE__ = JSON.parse($literal);'
      '</script></html>';
}

Map<String, Object?> _deviation(
  int id,
  String title, {
  bool withMedia = true,
}) => <String, Object?>{
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
  'media': withMedia
      ? <String, Object?>{
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
        }
      : <String, Object?>{},
};
