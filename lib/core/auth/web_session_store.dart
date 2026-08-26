import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Persists a lightweight snapshot of the DeviantArt *web* session (CSRF +
/// login flag + username) so a cold start restores it alongside the OAuth
/// session, instead of leaving the home feed signed out while the OAuth account
/// still shows in the app bar.
///
/// [write] also persists the deviantart.com cookies of a signed-in session.
/// The platform WebView store can lose cookies across an app update; keeping a
/// copy here lets the app re-inject them on the next cold start so the
/// personalized feed survives without asking the user to sign in again. The
/// cookies are session credentials and live in the app's own support
/// directory, the same container the WebView store already uses.
final class WebSessionStore {
  const WebSessionStore();

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/web_session.json');
  }

  Future<Map<String, Object?>> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const <String, Object?>{};
      final text = await file.readAsString();
      final data = jsonDecode(text);
      return data is Map<String, dynamic>
          ? data.cast<String, Object?>()
          : const <String, Object?>{};
    } on Object {
      return const <String, Object?>{};
    }
  }

  Future<void> write({
    required String csrf,
    required bool isLoggedIn,
    required String username,
    Map<String, String> cookies = const <String, String>{},
  }) async {
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode(<String, Object?>{
          'csrf': csrf,
          'isLoggedIn': isLoggedIn,
          'username': username,
          'cookies': cookies,
        }),
      );
    } on Object {
      // Best effort; a failed persist only means the next cold start re-asks
      // for the web sign-in.
    }
  }

  Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } on Object {
      // Best effort.
    }
  }
}
