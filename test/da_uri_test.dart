import 'package:daviewer/core/data/da_uri.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an artwork URL to an artwork route', () {
    final link = parseDeviantArtUrl(
      'https://www.deviantart.com/user/art/title-123456789',
    );
    expect(link?.route, '/artwork/123456789');
  });

  test('parses a fav.me shortcode', () {
    expect(parseDeviantArtUrl('https://fav.me/abc123')?.route, '/artwork/abc123');
  });

  test('parses a bare username to an artist route', () {
    expect(
      parseDeviantArtUrl('https://www.deviantart.com/someuser')?.route,
      '/artist/someuser',
    );
  });

  test('rejects non-DeviantArt hosts', () {
    expect(parseDeviantArtUrl('https://example.com/art/1'), isNull);
  });

  test('rejects reserved top-level paths as artists', () {
    expect(parseDeviantArtUrl('https://www.deviantart.com/gallery'), isNull);
  });

  test('returns null for empty input', () {
    expect(parseDeviantArtUrl('   '), isNull);
  });
}
