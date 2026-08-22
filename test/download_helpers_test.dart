import 'package:daviewer/features/downloads/download_helpers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('artworkIdFromTransfer recovers the artwork id', () {
    expect(artworkIdFromTransfer('artwork-abc-123-original'), 'abc-123');
    expect(
      artworkIdFromTransfer('artwork-97B067C2-XXXX-original'),
      '97B067C2-XXXX',
    );
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
