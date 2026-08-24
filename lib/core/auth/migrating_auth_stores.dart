import 'package:dakit_api/dakit_api.dart';
import 'package:dakit_core/dakit_core.dart';

/// Reads the current DAViewer Keychain item first, then the pre-0.2.126 item.
///
/// The macOS Keychain account name changed when the prompt was relabelled from
/// the plugin default to "DAViewer". Keychain treats that as a different item,
/// so a plain store swap makes an existing login look deleted. This adapter
/// copies the old value forward without deleting it until the user explicitly
/// signs out, which also keeps rollback safe.
final class MigratingTokenStore implements TokenStore {
  MigratingTokenStore({required this.primary, required this.legacy});

  final TokenStore primary;
  final TokenStore legacy;

  @override
  Future<AuthTokens?> read() async {
    Object? primaryError;
    StackTrace? primaryStack;
    try {
      final current = await primary.read();
      if (current != null) return current;
    } on Object catch (error, stack) {
      primaryError = error;
      primaryStack = stack;
    }

    final old = await legacy.read();
    if (old == null) {
      if (primaryError != null) {
        Error.throwWithStackTrace(primaryError, primaryStack!);
      }
      return null;
    }

    // Migration is best effort. The usable legacy session must still be
    // returned if an unsigned macOS build cannot write the renamed item.
    try {
      await primary.write(old);
    } on Object {
      // Keep the legacy value intact and use it for this process.
    }
    return old;
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    try {
      await primary.write(tokens);
    } on Object {
      // A Keychain-label or signing problem must not destroy a refreshed
      // session. Preserve it in the storage location the app could read.
      await legacy.write(tokens);
    }
  }

  @override
  Future<void> clear() => _clearBoth(primary.clear, legacy.clear);
}

/// Applies the same no-data-loss migration to an interrupted PKCE transaction.
final class MigratingPendingAuthorizationStore
    implements PendingAuthorizationStore {
  MigratingPendingAuthorizationStore({
    required this.primary,
    required this.legacy,
  });

  final PendingAuthorizationStore primary;
  final PendingAuthorizationStore legacy;

  @override
  Future<PendingAuthorization?> read() async {
    Object? primaryError;
    StackTrace? primaryStack;
    try {
      final current = await primary.read();
      if (current != null) return current;
    } on Object catch (error, stack) {
      primaryError = error;
      primaryStack = stack;
    }

    final old = await legacy.read();
    if (old == null) {
      if (primaryError != null) {
        Error.throwWithStackTrace(primaryError, primaryStack!);
      }
      return null;
    }
    try {
      await primary.write(old);
    } on Object {
      // The legacy transaction remains available for the current process.
    }
    return old;
  }

  @override
  Future<void> write(PendingAuthorization pending) async {
    try {
      await primary.write(pending);
    } on Object {
      await legacy.write(pending);
    }
  }

  @override
  Future<void> clear() => _clearBoth(primary.clear, legacy.clear);
}

Future<void> _clearBoth(
  Future<void> Function() clearPrimary,
  Future<void> Function() clearLegacy,
) async {
  Object? firstError;
  StackTrace? firstStack;
  try {
    await clearPrimary();
  } on Object catch (error, stack) {
    firstError = error;
    firstStack = stack;
  }
  try {
    await clearLegacy();
  } on Object catch (error, stack) {
    firstError ??= error;
    firstStack ??= stack;
  }
  if (firstError != null) {
    Error.throwWithStackTrace(firstError, firstStack!);
  }
}
