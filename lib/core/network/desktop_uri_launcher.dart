import 'dart:io';

import 'package:dakit_core/dakit_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens external URLs through platform-provided mechanisms.
///
/// On macOS the app runs inside an App Sandbox, where spawning `/usr/bin/open`
/// via [Process.run] is rejected (`deny process-exec`). `url_launcher` uses
/// `NSWorkspace.open`, which goes through LaunchServices and is sandbox-safe.
final class DesktopUriLauncher implements ExternalUriLauncher {
  const DesktopUriLauncher();

  @override
  Future<void> launch(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) throw _launchFailure(uri);
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
