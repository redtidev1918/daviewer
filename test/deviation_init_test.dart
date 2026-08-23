import 'dart:convert';
import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/core/data/deviation_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses uuid, writer description, tags, and additional media', () {
    final init = DeviationInitFetcher.parseInit(_fixture());

    expect(init.uuid, 'E9393CB8-E611-987D-6F97-5CE8DE66F4CB');
    // `writer` markup is HTML → collapsed to plain text.
    expect(init.description, 'Some practice.');
    expect(init.descriptionHtml, '<p>Some <b>practice</b>.</p>');
    expect(init.tags, <String>['elsevilla', 'arte']);
    expect(init.additionalMedia, hasLength(1));
    expect(init.additionalMedia.single.kind, MediaKind.image);
    expect(
      init.additionalMedia.single.uri.toString(),
      'https://images.example.test/page2.jpg/v1/fit/w_300/page2',
    );
  });

  test('tolerates a missing extended block without crashing', () {
    final init = DeviationInitFetcher.parseInit(<String, Object?>{
      'deviation': <String, Object?>{
        'deviationId': 1,
        'extended': <String, Object?>{'deviationUuid': 'UUID-1'},
      },
    });

    expect(init.uuid, 'UUID-1');
    expect(init.description, isNull);
    expect(init.tags, isEmpty);
    expect(init.additionalMedia, isEmpty);
  });

  test('throws FormatException when deviationUuid is missing', () {
    expect(
      () => DeviationInitFetcher.parseInit(<String, Object?>{
        'deviation': <String, Object?>{
          'deviationId': 1,
          'extended': <String, Object?>{},
        },
      }),
      throwsFormatException,
    );
  });

  const liveJsonPath = String.fromEnvironment('DA_DEVIATION_INIT_JSON');
  if (liveJsonPath.isNotEmpty) {
    test('parses a captured live dadeviation/init response', () {
      final data = jsonDecode(File(liveJsonPath).readAsStringSync());
      final init = DeviationInitFetcher.parseInit(data);

      expect(init.uuid, 'E9393CB8-E611-987D-6F97-5CE8DE66F4CB');
      expect(init.description, 'Some practice i did when i was on Twitch.');
      expect(init.tags, contains('elsevilla'));
    });
  }
}

Map<String, Object?> _fixture() => <String, Object?>{
  'deviation': <String, Object?>{
    'deviationId': 819241297,
    'extended': <String, Object?>{
      'deviationUuid': 'E9393CB8-E611-987D-6F97-5CE8DE66F4CB',
      'descriptionText': <String, Object?>{
        'html': <String, Object?>{
          'type': 'writer',
          'markup': '<p>Some <b>practice</b>.</p>',
        },
      },
      'tags': <Object?>[
        <String, Object?>{'name': 'elsevilla'},
        <String, Object?>{'name': 'arte'},
      ],
      'additionalMedia': <Object?>[
        <String, Object?>{
          'media': <String, Object?>{
            'baseUri': 'https://images.example.test/page2.jpg',
            'prettyName': 'page2',
            'token': <String>[],
            'types': <Object?>[
              <String, Object?>{
                't': '300W',
                'c': '/v1/fit/w_300/<prettyName>',
                'w': 300,
                'r': 0,
              },
            ],
          },
        },
      ],
    },
  },
};
