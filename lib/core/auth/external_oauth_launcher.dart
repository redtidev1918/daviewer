import 'package:dakit_core/dakit_core.dart';

import '../network/desktop_uri_launcher.dart';

/// Opens every authorization in the system browser and remembers the active
/// URL so the login screen can reopen the same PKCE transaction if needed.
final class ExternalOAuthLauncher implements ExternalUriLauncher {
  ExternalOAuthLauncher({ExternalUriLauncher? delegate})
    : _delegate = delegate ?? const DesktopUriLauncher();

  final ExternalUriLauncher _delegate;
  Uri? _authorizationUri;

  bool get canReopen => _authorizationUri != null;

  @override
  Future<void> launch(Uri uri) async {
    _authorizationUri = uri;
    try {
      await _delegate.launch(uri);
    } on Object {
      _authorizationUri = null;
      rethrow;
    }
  }

  Future<void> reopen() async {
    final uri = _authorizationUri;
    if (uri != null) await _delegate.launch(uri);
  }

  void finish() => _authorizationUri = null;
}
