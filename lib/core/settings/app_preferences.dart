import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../diagnostics/app_logger.dart';

/// Persists non-sensitive user preferences (language, theme mode) to a small
/// JSON file in the application-support directory, mirroring the pattern used
/// by [SearchHistoryStore]. Values are stored as plain strings so this store
/// stays independent of the UI-language and theme enums.
final class AppPreferences {
  const AppPreferences._();

  static const String _fileName = 'preferences.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}$_fileName');
  }

  /// Loads the persisted preferences. Missing or malformed values fall back to
  /// the defaults (`zh` / `system`).
  static Future<Map<String, String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return const <String, String>{'language': 'zh', 'themeMode': 'system'};
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map) {
        final language = decoded['language'];
        final themeMode = decoded['themeMode'];
        return <String, String>{
          'language': language == 'en' ? 'en' : 'zh',
          'themeMode': themeMode == 'light' || themeMode == 'dark'
              ? '$themeMode'
              : 'system',
        };
      }
    } on Object catch (error, stack) {
      AppLogger.instance.warning(
        'prefs',
        'failed to load preferences',
        error,
        stack,
      );
    }
    return const <String, String>{'language': 'zh', 'themeMode': 'system'};
  }

  static Future<void> saveLanguage(String language) =>
      _update((map) => map['language'] = language);

  static Future<void> saveThemeMode(String themeMode) =>
      _update((map) => map['themeMode'] = themeMode);

  static Future<void> _update(
    void Function(Map<String, Object?>) mutate,
  ) async {
    try {
      final file = await _file();
      final map = <String, Object?>{};
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map) {
          map.addAll(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
      mutate(map);
      await file.writeAsString(jsonEncode(map));
    } on Object catch (error, stack) {
      AppLogger.instance.warning(
        'prefs',
        'failed to save preferences',
        error,
        stack,
      );
    }
  }
}
