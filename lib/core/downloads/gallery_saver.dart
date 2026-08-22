import 'dart:async';
import 'dart:io';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

/// Copies completed image downloads into the system photo gallery on mobile
/// (Android/iOS), so downloaded artwork shows up in the user's album instead of
/// being buried inside the app's private directory.
///
/// Desktop platforms keep their normal file-system behaviour; this is a no-op
/// there (the gallery app does not exist).
final class GallerySaver {
  GallerySaver(this._transfers) {
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
    if (!_isMobile) return;
    if (!_isImage(snapshot.filename ?? path)) return;
    unawaited(_save(path));
  }

  Future<void> _save(String path) async {
    try {
      var ok = await Gal.hasAccess();
      if (!ok) ok = await Gal.requestAccess();
      if (!ok) return;
      await Gal.putImage(path);
      debugPrint('[gallery] saved to gallery: $path');
    } on Object catch (error) {
      debugPrint('[gallery] save failed: $error');
    }
  }

  static bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  Future<void> dispose() => _subscription.cancel();
}
