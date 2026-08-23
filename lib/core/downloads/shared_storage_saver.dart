import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

/// Moves completed downloads into the system's public Downloads folder so they
/// are discoverable outside the app's private directory — without duplicating
/// the file or requesting a gallery permission.
///
/// On Android, `dakit_flutter` 0.1.9 keeps an app-readable private copy while
/// exposing the shared copy, so in-app preview keeps working under scoped
/// storage.
final class SharedStorageSaver {
  SharedStorageSaver(this._transfers) {
    _subscription = _transfers.updates.listen(_onUpdate);
  }

  final TransferManager _transfers;
  late final StreamSubscription<TransferSnapshot> _subscription;
  final Set<String> _handled = <String>{};

  void _onUpdate(TransferSnapshot snapshot) {
    if (snapshot.state != TransferState.completed) return;
    final path = snapshot.localPath;
    if (path == null || path.isEmpty) return;
    if (!_handled.add(snapshot.id)) return;
    unawaited(_move(snapshot.id));
  }

  Future<void> _move(String id) async {
    try {
      final path = await _transfers.moveToSharedStorage(
        id,
        TransferSharedStorage.downloads,
      );
      debugPrint('[downloads] moved to $path');
    } on Object catch (error) {
      debugPrint('[downloads] move failed: $error');
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
