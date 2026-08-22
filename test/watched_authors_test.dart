import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/features/home/home_providers.dart';
import 'package:flutter_test/flutter_test.dart';

Artwork _artwork(String id, String username, DateTime? time) => Artwork(
  id: id,
  title: 't',
  author: UserProfile(id: 'u-$username', username: username),
  pageUri: Uri.parse('https://d.test/$id'),
  media: const <MediaAsset>[],
  publishedAt: time,
);

void main() {
  test('groups deviations by author and keeps the newest time', () {
    final result = watchedAuthorsFrom(<Artwork>[
      _artwork('1', 'alice', DateTime(2026, 1, 3)),
      _artwork('2', 'bob', DateTime(2026, 1, 5)),
      _artwork('3', 'alice', DateTime(2026, 1, 1)),
    ]);

    expect(
      result.map((a) => a.username),
      containsAll(<String>['alice', 'bob']),
    );
    expect(result.length, 2);
    final alice = result.firstWhere((a) => a.username == 'alice');
    expect(alice.lastUpdate, DateTime(2026, 1, 3));
  });

  test('sorts authors newest first', () {
    final result = watchedAuthorsFrom(<Artwork>[
      _artwork('1', 'alice', DateTime(2026, 1, 1)),
      _artwork('2', 'bob', DateTime(2026, 1, 3)),
      _artwork('3', 'carol', DateTime(2026, 1, 2)),
    ]);

    expect(result.map((a) => a.username).toList(), <String>[
      'bob',
      'carol',
      'alice',
    ]);
  });

  test('skips empty usernames and sorts null times last', () {
    final result = watchedAuthorsFrom(<Artwork>[
      _artwork('1', '', DateTime(2026, 1, 1)),
      _artwork('2', 'alice', null),
      _artwork('3', 'bob', DateTime(2026, 1, 2)),
    ]);

    expect(result.map((a) => a.username).toList(), <String>['bob', 'alice']);
  });
}
