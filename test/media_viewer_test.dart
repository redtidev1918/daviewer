import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/features/artwork/media_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

MediaAsset asset(
  String id,
  MediaKind kind, {
  MediaRole role = MediaRole.preview,
  Uri? uri,
  int? width,
  MediaAvailability availability = MediaAvailability.available,
}) => MediaAsset(
  id: id,
  kind: kind,
  role: role,
  availability: availability,
  uri: uri,
  width: width,
);

void main() {
  test('returns null for empty media', () {
    expect(selectDisplayAsset(const <MediaAsset>[]), isNull);
  });

  test('prefers a playable video', () {
    final video = asset(
      'v',
      MediaKind.video,
      uri: Uri.parse('https://x/v.mp4'),
    );
    final image = asset(
      'i',
      MediaKind.image,
      uri: Uri.parse('https://x/i.jpg'),
    );
    expect(selectDisplayAsset(<MediaAsset>[image, video])?.id, 'v');
  });

  test('skips a video without a URI', () {
    final video = asset('v', MediaKind.video);
    final image = asset(
      'i',
      MediaKind.image,
      uri: Uri.parse('https://x/i.jpg'),
    );
    expect(selectDisplayAsset(<MediaAsset>[video, image])?.id, 'i');
  });

  test('prefers an animation over images', () {
    final anim = asset(
      'a',
      MediaKind.animation,
      uri: Uri.parse('https://x/a.swf'),
    );
    final image = asset(
      'i',
      MediaKind.image,
      uri: Uri.parse('https://x/i.jpg'),
    );
    expect(selectDisplayAsset(<MediaAsset>[image, anim])?.id, 'a');
  });

  test('picks the largest preview image', () {
    final small = asset(
      's',
      MediaKind.image,
      width: 400,
      uri: Uri.parse('https://x/s.jpg'),
    );
    final large = asset(
      'l',
      MediaKind.image,
      width: 1000,
      uri: Uri.parse('https://x/l.jpg'),
    );
    expect(selectDisplayAsset(<MediaAsset>[small, large])?.id, 'l');
  });

  test('falls back to any image when no preview exists', () {
    final original = asset(
      'o',
      MediaKind.image,
      role: MediaRole.original,
      uri: Uri.parse('https://x/o.jpg'),
    );
    expect(selectDisplayAsset(<MediaAsset>[original])?.id, 'o');
  });

  test('prefers an accessible preview over gated full-size content', () {
    final gatedContent = asset(
      'content',
      MediaKind.image,
      width: 2400,
      uri: Uri.parse('https://x/content.jpg'),
      availability: MediaAvailability.purchaseRequired,
    );
    final preview = asset(
      'preview',
      MediaKind.image,
      width: 800,
      uri: Uri.parse('https://x/preview.jpg'),
    );
    expect(
      selectDisplayAsset(<MediaAsset>[gatedContent, preview])?.id,
      'preview',
    );
  });
}
