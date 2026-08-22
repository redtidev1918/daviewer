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
}
