import 'package:daviewer/core/data/web_user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses watchers, join date, and tagline from the about payload', () {
    final info = WebUserProfileFetcher.parseJson(<String, Object?>{
      'owner': <String, Object?>{
        'userId': 414281,
        'username': 'loish',
        'usericon': 'https://a.deviantart.net/avatar.png',
      },
      'pageExtraData': <String, Object?>{
        'gruserTagline': 'Lois van Baarle',
        'joinDate': '2003-05-24T09:33:00-0700',
        'stats': <String, Object?>{
          'deviations': 499,
          'watchers': 240536,
          'favourites': 599,
        },
      },
    });

    expect(info.watchers, 240536);
    expect(info.joinDate, DateTime.parse('2003-05-24T09:33:00-0700'));
    expect(info.tagline, 'Lois van Baarle');
  });

  test('degrades gracefully when the payload is reshaped', () {
    expect(
      WebUserProfileFetcher.parseJson(<String, Object?>{}).watchers,
      isNull,
    );
    expect(WebUserProfileFetcher.parseJson('not a map').joinDate, isNull);
    expect(
      WebUserProfileFetcher.parseJson(<String, Object?>{
        'pageExtraData': <String, Object?>{
          'stats': <String, Object?>{'watchers': 'n/a'},
        },
      }).watchers,
      isNull,
    );
  });
}
