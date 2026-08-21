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

  /// Merges both callback streams concurrently.
  ///
  /// The app-link stream is long-lived and never closes, so a sequential
  /// `yield*` over it would block forever and never observe WebView callbacks.
  /// Subscribe to both sources at once and forward whichever emits a matching
  /// redirect first.
  @override
  Stream<Uri> get uris => Stream<Uri>.multi((controller) {
    void onData(Uri uri) => controller.add(uri);
    void onError(Object error, StackTrace stack) =>
        controller.addError(error, stack);

    final subscriptions = <StreamSubscription<Uri>>[
      _initialSource.uris.listen(onData, onError: onError),
      _webViewCallbacks.listen(onData, onError: onError),
    ];
    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
  });
}
