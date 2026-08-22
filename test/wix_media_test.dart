import 'package:daviewer/core/data/wix_media.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('withWixToken', () {
    test('appends the first token when no type index is given', () {
      expect(
        withWixToken('https://x.test/a.jpg', null, const ['tok']),
        'https://x.test/a.jpg?token=tok',
      );
    });

    test('uses the r-indexed token when valid', () {
      final type = <Object?, Object?>{'r': 1};
      expect(
        withWixToken('https://x.test/a.jpg', type, const ['a', 'b']),
        'https://x.test/a.jpg?token=b',
      );
    });

    test('falls back to the first token for an invalid index', () {
      final type = <Object?, Object?>{'r': 99};
      expect(
        withWixToken('https://x.test/a.jpg', type, const ['a', 'b']),
        'https://x.test/a.jpg?token=a',
      );
    });

    test('returns unchanged without tokens', () {
      expect(
        withWixToken('https://x.test/a.jpg', null, const []),
        'https://x.test/a.jpg',
      );
    });

    test('uses & when the URL already has a query', () {
      expect(
        withWixToken('https://x.test/a.jpg?x=1', null, const ['tok']),
        'https://x.test/a.jpg?x=1&token=tok',
      );
    });
  });

  group('wixTypeNamed / wixLargestImageType', () {
    const types = <Object?>[
      {'t': '150', 'c': 'v1/fit/w_150', 'w': 150},
      {'t': 'preview', 'c': 'v1/fill/w_222', 'w': 222},
      {'t': 'fullview', 'c': 'v1/fill/w_1280', 'w': 1280},
    ];

    test('finds a named type', () {
      expect(wixTypeNamed(types, 'fullview')?['t'], 'fullview');
    });

    test('returns null for a missing name', () {
      expect(wixTypeNamed(types, 'nope'), isNull);
    });

    test('picks the largest resampled type', () {
      expect(wixLargestImageType(types)?['t'], 'fullview');
    });
  });

  group('wixResampledUrl', () {
    const types = <Object?>[
      {'t': '150', 'c': 'v1/fit/w_150/<prettyName>', 'w': 150, 'r': 0},
      {'t': 'fullview', 'c': 'v1/fill/w_1280/<prettyName>', 'w': 1280, 'r': 1},
    ];
    const tokens = ['tok0', 'tok1'];

    test('returns null when base is missing or empty', () {
      expect(wixResampledUrl(null, 'pretty', tokens, types), isNull);
      expect(wixResampledUrl('', 'pretty', tokens, types), isNull);
    });

    test('picks the type closest to targetWidth and substitutes the name', () {
      expect(
        wixResampledUrl(
          'https://wix.test/img',
          'pretty',
          tokens,
          types,
          targetWidth: 200,
        ),
        Uri.parse('https://wix.test/imgv1/fit/w_150/pretty?token=tok0'),
      );
    });

    test('picks the largest type when targetWidth is null', () {
      expect(
        wixResampledUrl('https://wix.test/img', 'pretty', tokens, types),
        Uri.parse('https://wix.test/imgv1/fill/w_1280/pretty?token=tok1'),
      );
    });

    test('falls back to the raw base with token when no resampled type', () {
      expect(
        wixResampledUrl('https://wix.test/img.jpg', 'pretty', tokens, const []),
        Uri.parse('https://wix.test/img.jpg?token=tok0'),
      );
    });
  });
}
