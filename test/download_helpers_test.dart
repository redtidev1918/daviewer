import 'package:daviewer/features/downloads/download_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artworkIdFromTransfer recovers the artwork id', () {
    expect(artworkIdFromTransfer('artwork-abc-123-original'), 'abc-123');
    expect(
      artworkIdFromTransfer('artwork-97B067C2-XXXX-original'),
      '97B067C2-XXXX',
    );
    expect(artworkIdFromTransfer('artwork-abc-123-image-2'), 'abc-123');
  });

  test('image transfer ids are stable and distinct per asset', () {
    final first = imageTransferId('abc-123', 'abc:page:1');
    final second = imageTransferId('abc-123', 'abc:page:2');

    expect(first, 'artwork-abc-123-image-YWJjOnBhZ2U6MQ');
    expect(second, isNot(first));
    expect(artworkIdFromTransfer(first), 'abc-123');
  });

  test('artworkIdFromTransfer returns null for other schemes', () {
    expect(artworkIdFromTransfer('other-id'), isNull);
    expect(artworkIdFromTransfer('artwork-'), isNull);
    expect(artworkIdFromTransfer('artwork--original'), isNull);
  });

  test('isImageFile detects image extensions case-insensitively', () {
    expect(isImageFile('/a/b.jpg'), isTrue);
    expect(isImageFile('/a/b.PNG'), isTrue);
    expect(isImageFile('/a/b.webp'), isTrue);
    expect(isImageFile('/a/b.gif'), isTrue);
    expect(isImageFile('/a/b.mp4'), isFalse);
    expect(isImageFile('/a/b.txt'), isFalse);
  });
}
