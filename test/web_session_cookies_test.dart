import 'dart:convert';

import 'package:daviewer/core/auth/web_session_controller.dart';
import 'package:daviewer/core/data/web_session.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal CookieManager stub: returns a fixed cookie list (or throws to
/// simulate the manager being unavailable early in startup).
class _FakeCookieManager extends Fake implements CookieManager {
  _FakeCookieManager(this._cookies);

  final List<Cookie>? _cookies;

  @override
  Future<List<Cookie>> getCookies({
    required WebUri url,
    InAppWebViewController? webViewController,
    @Deprecated('Use webViewController instead')
    InAppWebViewController? iosBelow11WebViewController,
  }) async {
    final cookies = _cookies;
    if (cookies == null) throw StateError('unavailable');
    return cookies;
  }
}

/// A DeviantArt `userinfo` cookie value carrying [username].
String _userInfo(String username) => Uri.encodeComponent(
  'irrelevant;${jsonEncode(<String, String>{'username': username})}',
);

void main() {
  group('WebSession.cookies', () {
    test('returns name -> value map of the deviantart cookies', () async {
      final session = WebSession(
        () => _FakeCookieManager(<Cookie>[
          Cookie(name: 'userinfo', value: 'abc'),
          Cookie(name: 'csrf', value: 'tok'),
        ]),
      );

      expect(await session.cookies(), <String, String>{
        'userinfo': 'abc',
        'csrf': 'tok',
      });
    });

    test('serializes into a Cookie header value', () async {
      final session = WebSession(
        () => _FakeCookieManager(<Cookie>[
          Cookie(name: 'a', value: '1'),
          Cookie(name: 'b', value: '2'),
        ]),
      );

      expect(await session.cookieHeader(), 'a=1; b=2');
    });

    test('returns empty map/header when the cookie manager throws', () async {
      final session = WebSession(() => _FakeCookieManager(null));

      expect(await session.cookies(), isEmpty);
      expect(await session.cookieHeader(), '');
    });
  });

  group('WebSession.usernameFromUserInfo', () {
    test('reads the username from a real-looking userinfo cookie', () {
      expect(
        WebSession.usernameFromUserInfo(_userInfo('CoolArtist')),
        'CoolArtist',
      );
    });

    test('returns empty for anonymous, malformed, or missing values', () {
      expect(WebSession.usernameFromUserInfo(null), '');
      expect(WebSession.usernameFromUserInfo(''), '');
      expect(WebSession.usernameFromUserInfo('not-a-cookie'), '');
      expect(WebSession.usernameFromUserInfo('a=1; b=2'), '');
    });
  });

  group('formatCookieExport / parseImportedCookies', () {
    test('exported JSON round-trips back to the same cookie map', () {
      final cookies = <String, String>{
        'userinfo': _userInfo('Artist'),
        'csrf': 'tok',
      };

      final exported = formatCookieExport(cookies);
      expect(exported.contains('userinfo'), isTrue);
      expect(parseImportedCookies(exported), cookies);
    });

    test('parses a Cookie header form', () {
      expect(parseImportedCookies('a=1; b=two; x'), <String, String>{
        'a': '1',
        'b': 'two',
      });
    });

    test('parses a browser-extension JSON array, skipping other domains', () {
      final text = jsonEncode(<Map<String, String>>[
        <String, String>{
          'domain': '.deviantart.com',
          'name': 'userinfo',
          'value': 'v1',
        },
        <String, String>{
          'domain': '.example.com',
          'name': 'tracker',
          'value': 'x',
        },
        <String, String>{'name': 'csrf', 'value': 'tok'},
      ]);

      expect(parseImportedCookies(text), <String, String>{
        'userinfo': 'v1',
        'csrf': 'tok',
      });
    });

    test('returns null for empty or unrecognizable input', () {
      expect(parseImportedCookies(''), isNull);
      expect(parseImportedCookies('   '), isNull);
      expect(parseImportedCookies('garbage without equals'), isNull);
      expect(parseImportedCookies('{"unexpected": 123}'), <String, String>{});
      expect(parseImportedCookies('[]'), isNull);
    });
  });

  group('evaluateCookieImportIdentity', () {
    test('allows import when no identity exists yet', () {
      expect(
        evaluateCookieImportIdentity(
          importedUsername: 'artist',
          oauthUsername: null,
          currentWebUsername: '',
        ),
        isNull,
      );
    });

    test('allows import when every existing identity matches', () {
      expect(
        evaluateCookieImportIdentity(
          importedUsername: 'Artist',
          oauthUsername: 'artist',
          currentWebUsername: 'ARTIST',
        ),
        isNull,
      );
    });

    test('rejects cookies without a signed-in userinfo session', () {
      expect(
        evaluateCookieImportIdentity(
          importedUsername: '',
          oauthUsername: null,
          currentWebUsername: '',
        ),
        CookieImportOutcome.anonymous,
      );
    });

    test('rejects import that conflicts with the OAuth account', () {
      expect(
        evaluateCookieImportIdentity(
          importedUsername: 'other',
          oauthUsername: 'artist',
          currentWebUsername: '',
        ),
        CookieImportOutcome.accountConflict,
      );
    });

    test('rejects import that conflicts with the live web session', () {
      expect(
        evaluateCookieImportIdentity(
          importedUsername: 'other',
          oauthUsername: null,
          currentWebUsername: 'artist',
        ),
        CookieImportOutcome.accountConflict,
      );
    });
  });
}
