import 'dart:io';

import 'package:dakit_core/dakit_core.dart';

final class DesktopUriLauncher implements ExternalUriLauncher {
  const DesktopUriLauncher();

  @override
  Future<void> launch(Uri uri) async {
    if (Platform.isMacOS) {
      final result = await Process.run('open', <String>[uri.toString()]);
      if (result.exitCode != 0) throw _launchFailure(uri);
      return;
    }
    if (Platform.isWindows) {
      final result = await Process.run('cmd', <String>[
        '/c',
        'start',
        '',
        uri.toString(),
      ]);
      if (result.exitCode != 0) throw _launchFailure(uri);
      return;
    }
    if (Platform.isLinux) {
      final result = await Process.run('xdg-open', <String>[uri.toString()]);
      if (result.exitCode != 0) throw _launchFailure(uri);
      return;
    }
    throw _launchFailure(uri);
  }

  DAKitException _launchFailure(Uri uri) {
    return DAKitException(
      kind: DAKitFailureKind.authentication,
      code: 'oauth.browser.launch_failed',
      message: 'The operating system could not open the authorization URL.',
      details: <String, Object?>{'uri': uri.toString()},
    );
  }
}
