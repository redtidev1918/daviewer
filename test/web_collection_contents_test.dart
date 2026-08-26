import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:daviewer/core/data/web_collection_contents.dart';
import 'package:dio/dio.dart';
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

  test('parses a gallection/contents JSON page', () {
    final page = WebCollectionContentsFetcher.parseJsonPage(<String, Object?>{
      'hasMore': true,
      'nextOffset': 24,
      'estimatedTotal': 284,
      'results': <Object?>[
        _deviation(10, 'Json result'),
        _deviation(11, 'Another result'),
      ],
    });

    expect(page.hasMore, isTrue);
    expect(page.items.map((artwork) => artwork.id), <String>['10', '11']);
    expect(page.items.first.author.username, 'ArtistOne');
    expect(page.items.first.media, isNotEmpty);
  });

  test('extracts the collection cover from the JSON response', () {
    final page = WebCollectionContentsFetcher.parseJsonPage(<String, Object?>{
      'hasMore': false,
      'results': <Object?>[],
      'gallection': <String, Object?>{
        'folderId': 1161139,
        'thumb': _deviation(99, 'Cover'),
      },
    });

    expect(page.coverUri, isNotNull);
    expect(page.coverUri.toString(), contains('work-99'));
  });

  test('throws FormatException when JSON results are missing', () {
    expect(
      () => WebCollectionContentsFetcher.parseJsonPage(<String, Object?>{
        'hasMore': false,
      }),
      throwsFormatException,
    );
  });

  test('scraps request uses type=gallery and scraps_folder=true', () async {
    final captured = <Map<String, dynamic>>[];
    final dio = Dio(
      BaseOptions(baseUrl: 'https://www.deviantart.com'),
    )..httpClientAdapter = _CaptureAdapter(captured, body: <String, Object?>{
        'hasMore': false,
        'results': <Object?>[_deviation(30, 'Scrap 30')],
      });

    final page = await WebCollectionContentsFetcher(dio).fetchScrapsPage(
      username: 'ArtistOne',
      cookieHeader: 'userinfo=x',
      csrfToken: 'csrf123',
    );

    expect(page.items.map((artwork) => artwork.id), <String>['30']);
    final query = captured.single;
    expect(query['type'], 'gallery');
    expect(query['scraps_folder'], true);
    expect(query['username'], 'artistone');
    expect(query['mature_content'], true);
    expect(query['csrf_token'], 'csrf123');
    expect(query['offset'], 0);
    expect(query['limit'], 24);
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

  const liveJsonPath = String.fromEnvironment('DA_COLLECTION_JSON');
  if (liveJsonPath.isNotEmpty) {
    test('parses a captured live gallection/contents JSON response', () {
      final data = jsonDecode(File(liveJsonPath).readAsStringSync());
      final page = WebCollectionContentsFetcher.parseJsonPage(data);

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

/// Captures the outgoing query parameters of one Dio request and returns a
/// canned JSON body, so fetcher request shapes can be asserted without
/// touching the network.
final class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.captured, {required this.body});

  final List<Map<String, dynamic>> captured;
  final Map<String, Object?> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(Map<String, dynamic>.of(options.queryParameters));
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
