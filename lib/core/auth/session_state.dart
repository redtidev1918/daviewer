import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/web_session.dart';
import '../runtime/runtime_provider.dart';

/// Reads the deviantart.com web session cookies.
final webSessionProvider = Provider<WebSession>(
  (ref) => WebSession(() {
    final manager = ref.read(runtimeProvider).webViewProxyManager;
    if (manager == null) {
      throw StateError('WebView cookie manager is unavailable');
    }
    return manager.cookieManager;
  }),
);
