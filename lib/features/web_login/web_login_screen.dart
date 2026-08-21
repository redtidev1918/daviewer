import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/auth/webview_oauth_bridge.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';

/// Hosts the embedded DeviantArt WebView.
///
/// This screen owns the deviantart.com web session. It is opened to let the
/// user sign in on the web (for the personalized `rfy/deviations` home feed)
/// and also receives DAKit OAuth authorize URLs so an existing web session can
/// complete OAuth without re-entering credentials.
final class WebLoginScreen extends ConsumerStatefulWidget {
  const WebLoginScreen({super.key});

  @override
  ConsumerState<WebLoginScreen> createState() => _WebLoginScreenState();
}

final class _WebLoginScreenState extends ConsumerState<WebLoginScreen> {
  static final Uri _loginUri = Uri.parse(
    'https://www.deviantart.com/users/login',
  );
  static final Uri _homeUri = Uri.parse('https://www.deviantart.com/');

  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _launchSub;
  Uri? _pendingAuthUri;
  bool _loading = true;
  double _progress = 0;

  WebViewOAuthBridge? get _bridge =>
      ref.read(runtimeProvider).webViewOAuthBridge;

  @override
  void initState() {
    super.initState();
    final bridge = _bridge;
    if (bridge != null) {
      _launchSub = bridge.launchRequests.listen(_loadAuthRequest);
    }
  }

  @override
  void dispose() {
    unawaited(_launchSub?.cancel());
    super.dispose();
  }

  void _loadAuthRequest(Uri uri) {
    final controller = _controller;
    if (controller == null) {
      _pendingAuthUri = uri;
      return;
    }
    controller.loadUrl(urlRequest: URLRequest(url: WebUri(uri.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);

    // When an OAuth login finishes, close this screen so the user lands back
    // on the (now signed-in) native home instead of manually tapping "done".
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.status != AuthStatus.signedIn &&
          next.status == AuthStatus.signedIn &&
          mounted) {
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(s.webLogin),
        actions: <Widget>[
          IconButton(
            tooltip: s.done,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
          ),
        ],
        bottom: _loading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  value: _progress > 0 && _progress < 1 ? _progress : null,
                ),
              )
            : null,
      ),
      body: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(_loginUri.toString())),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            transparentBackground: true,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            final pending = _pendingAuthUri;
            if (pending != null) {
              _pendingAuthUri = null;
              controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(pending.toString())),
              );
            }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri != null && uri.scheme == 'dakit' && uri.host == 'oauth') {
              _bridge?.addCallback(uri);
              controller.loadUrl(
                urlRequest: URLRequest(url: WebUri(_homeUri.toString())),
              );
              return NavigationActionPolicy.CANCEL;
            }
            return NavigationActionPolicy.ALLOW;
          },
          onLoadStart: (controller, url) {
            if (mounted) setState(() => _loading = true);
          },
          onLoadStop: (controller, url) {
            if (mounted) setState(() => _loading = false);
          },
          onProgressChanged: (controller, progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
        ),
      ),
    );
  }
}
