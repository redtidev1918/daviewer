import 'dart:async';

import 'package:dakit_core/dakit_core.dart';

/// Combines the OS app-link callback source with callbacks captured from the
/// in-app WebView, so both external-browser OAuth and WebView OAuth work.
final class CombinedCallbackUriSource implements InitialCallbackUriSource {
  CombinedCallbackUriSource(this._initialSource, this._webViewCallbacks);

  final InitialCallbackUriSource _initialSource;
  final Stream<Uri> _webViewCallbacks;

  @override
  Future<Uri?> initialUri() => _initialSource.initialUri();

  @override
  Stream<Uri> get uris async* {
    yield* _initialSource.uris;
    yield* _webViewCallbacks;
  }
}
