import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Whether the previous process reported an uncaught error. Consumed once at
/// startup and exposed so the diagnostics screen can offer to report it. This
/// is purely local — no network, no analytics.
final crashDetectedProvider = Provider<bool>((ref) => false);

/// Records that the current process hit an uncaught error, and lets the next
/// launch consume that marker. The marker is a local file: written by the
/// global error handler and deleted after it is read on the next start.
final class CrashMarker {
  const CrashMarker._();

  static Future<File> _file() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}${Platform.pathSeparator}last_crash.txt');
  }

  static Future<void> record() async {
    try {
      final file = await _file();
      await file.writeAsString(DateTime.now().toIso8601String());
    } on Object {
      // Best effort: crash marking must never add a second failure.
    }
  }

  static Future<bool> consume() async {
    try {
      final file = await _file();
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } on Object {
      // Best effort.
    }
    return false;
  }
}
