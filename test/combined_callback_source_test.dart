import 'dart:async';

import 'package:dakit_core/dakit_core.dart';
import 'package:daviewer/core/auth/combined_callback_source.dart';
import 'package:flutter_test/flutter_test.dart';

/// An app-link source whose stream never closes, matching the real
/// `AppLinksCallbackUriSource` behavior. A sequential `yield*` over this
/// stream would starve the WebView callbacks forever.
final class _NeverClosingCallbackSource implements InitialCallbackUriSource {
  final StreamController<Uri> _controller = StreamController<Uri>();

  @override
  Future<Uri?> initialUri() async => null;

  @override
  Stream<Uri> get uris => _controller.stream;
}

void main() {
  test(
    'delivers WebView callbacks even when the app-link stream never closes',
    () async {
      final webViewCallbacks = StreamController<Uri>.broadcast();
      final source = CombinedCallbackUriSource(
        _NeverClosingCallbackSource(),
        webViewCallbacks.stream,
      );

      final first = source.uris.first;
      final callback = Uri.parse('dakit://oauth/callback?code=x&state=y');
      webViewCallbacks.add(callback);

      expect(await first, callback);

      await webViewCallbacks.close();
    },
  );
}
