import 'dart:async';
import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';

/// Moves completed downloads into the system's public Downloads folder so they
/// are discoverable outside the app's private directory — without duplicating
/// the file or requesting a gallery permission.
///
/// Android is excluded: scoped storage (API 29+) does not let the app read back
/// a file moved into public Downloads via MediaStore, so the downloads page
/// could not preview it (`FileImage` fails). Keeping Android downloads in
/// app-private storage keeps preview and deletion working.
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
    if (!kIsWeb && Platform.isAndroid) return;
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
