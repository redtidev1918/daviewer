import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/auth/migrating_auth_stores.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final tokens = AuthTokens(
    accessToken: 'access',
    tokenType: 'Bearer',
    expiresAt: DateTime.utc(2030),
    refreshToken: 'refresh',
    scopes: const <String>{'basic'},
  );

  test('legacy OAuth session is copied forward without being deleted', () async {
    final primary = _MemoryTokenStore();
    final legacy = _MemoryTokenStore(tokens);
    final store = MigratingTokenStore(primary: primary, legacy: legacy);

    expect(await store.read(), same(tokens));
    expect(await primary.read(), same(tokens));
    expect(await legacy.read(), same(tokens));
  });

  test('legacy OAuth session remains usable when renamed store rejects writes', () async {
    final primary = _MemoryTokenStore()..failWrites = true;
    final legacy = _MemoryTokenStore(tokens);
    final store = MigratingTokenStore(primary: primary, legacy: legacy);

    expect(await store.read(), same(tokens));
    expect(await legacy.read(), same(tokens));
  });

  test('refresh falls back to legacy storage and logout clears both', () async {
    final primary = _MemoryTokenStore()..failWrites = true;
    final legacy = _MemoryTokenStore(tokens);
    final store = MigratingTokenStore(primary: primary, legacy: legacy);
    final refreshed = AuthTokens(
      accessToken: 'new',
      tokenType: 'Bearer',
      expiresAt: DateTime.utc(2031),
    );

    await store.write(refreshed);
    expect(await legacy.read(), same(refreshed));
    await store.clear();
    expect(await primary.read(), isNull);
    expect(await legacy.read(), isNull);
  });

  test('pending OAuth transaction is migrated too', () async {
    final pending = PendingAuthorization(
      authorizationUri: Uri.parse('https://www.deviantart.com/oauth2/authorize'),
      state: 'state',
      codeVerifier: 'verifier',
      createdAt: DateTime.utc(2030),
    );
    final primary = _MemoryPendingStore();
    final legacy = _MemoryPendingStore(pending);
    final store = MigratingPendingAuthorizationStore(
      primary: primary,
      legacy: legacy,
    );

    expect(await store.read(), same(pending));
    expect(await primary.read(), same(pending));
    expect(await legacy.read(), same(pending));
  });
}

final class _MemoryTokenStore implements TokenStore {
  _MemoryTokenStore([this.value]);

  AuthTokens? value;
  bool failWrites = false;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<AuthTokens?> read() async => value;

  @override
  Future<void> write(AuthTokens tokens) async {
    if (failWrites) throw StateError('write rejected');
    value = tokens;
  }
}

final class _MemoryPendingStore implements PendingAuthorizationStore {
  _MemoryPendingStore([this.value]);

  PendingAuthorization? value;

  @override
  Future<void> clear() async => value = null;

  @override
  Future<PendingAuthorization?> read() async => value;

  @override
  Future<void> write(PendingAuthorization pending) async => value = pending;
}
