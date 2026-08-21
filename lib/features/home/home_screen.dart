import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/webview_oauth_bridge.dart';
import '../../core/runtime/runtime_provider.dart';

/// Home tab backed by the real DeviantArt home page.
///
/// The web home page uses DeviantArt's own `rfy/deviations` recommendation
/// engine (web-session based). Embedding the page gives the app exactly the
/// same personalized home feed as the web version.
///
/// This same WebView also owns the deviantart.com web-session cookies. When
/// the user starts native OAuth login, the bridge loads the OAuth authorize
/// URL here so an already logged-in web session can complete OAuth without
/// re-entering credentials.
final class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends ConsumerState<HomeScreen> {
  InAppWebViewController? _controller;
  StreamSubscription<Uri>? _launchSub;
  Uri? _pendingAuthUri;
  bool _loading = true;
  Object? _error;

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
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri('https://www.deviantart.com/'),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                final pending = _pendingAuthUri;
                if (pending != null) {
                  _pendingAuthUri = null;
                  controller.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri(pending.toString()),
                    ),
                  );
                }
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final uri = navigationAction.request.url;
                if (uri != null &&
                    uri.scheme == 'dakit' &&
                    uri.host == 'oauth') {
                  _bridge?.addCallback(uri);
                  // Return to the web home after completing/cancelling the
                  // OAuth redirect in the WebView.
                  controller.loadUrl(
                    urlRequest: URLRequest(
                      url: WebUri('https://www.deviantart.com/'),
                    ),
                  );
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) {
                if (mounted) {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                }
              },
              onLoadStop: (controller, url) {
                if (mounted) {
                  setState(() {
                    _loading = false;
                    _error = null;
                  });
                }
              },
              onReceivedError: (controller, request, error) {
                if (mounted) {
                  setState(() {
                    _error = error.description;
                    _loading = false;
                  });
                }
              },
            ),
            if (_loading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0xfff7f9fc),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: ColoredBox(
                  color: const Color(0xfff7f9fc),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.error_outline, size: 48),
                        const SizedBox(height: 12),
                        Text('$_error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: _reload,
                          child: const Text('重试 / Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await controller.reload();
  }
}
