import 'package:daviewer/core/sharing/app_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds canonical artist links', () {
    expect(
      artistShareUri('RabidBunny1').toString(),
      'https://www.deviantart.com/rabidbunny1',
    );
  });

  test('builds gallery and collection links from the folder kind', () {
    expect(
      folderShareUri(
        username: 'Artist',
        folderId: '82858026',
        isCollection: false,
      ).toString(),
      'https://www.deviantart.com/artist/gallery/82858026',
    );
    expect(
      folderShareUri(
        username: 'Artist',
        folderId: '42',
        isCollection: true,
      ).toString(),
      'https://www.deviantart.com/artist/favourites/42',
    );
  });

  test('encodes tags as a single URL path segment', () {
    expect(
      tagShareUri('digital art').toString(),
      'https://www.deviantart.com/tag/digital%20art',
    );
  });
}
