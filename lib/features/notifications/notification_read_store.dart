import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../core/diagnostics/app_logger.dart';

/// Persists locally "read" notification ids so their unread dots stay dismissed
/// across visits. DeviantArt exposes no public "mark read" endpoint, so this is
/// a client-side overlay on top of the server-provided `isNew` flag.
final class NotificationReadStore {
  const NotificationReadStore._();

  static const String _fileName = 'notifications_read.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  static Future<Set<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return <String>{};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is List) {
        return decoded.whereType<String>().toSet();
      }
    } on Object catch (error, stack) {
      AppLogger.instance.warning(
        'notifications',
        'failed to load read ids',
        error,
        stack,
      );
    }
    return <String>{};
  }

  static Future<Set<String>> addAll(Iterable<String> ids) async {
    final read = await load();
    read.addAll(ids.where((id) => id.isNotEmpty));
    await _write(read);
    return read;
  }

  static Future<Set<String>> add(String id) => addAll(<String>[id]);

  static Future<void> _write(Set<String> read) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode(read.toList(growable: false)));
    } on Object catch (error, stack) {
      AppLogger.instance.warning(
        'notifications',
        'failed to save read ids',
        error,
        stack,
      );
    }
  }
}
