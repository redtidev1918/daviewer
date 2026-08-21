import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Home tab backed by the real DeviantArt home page.
///
/// The web home page uses DeviantArt's own `rfy/deviations` recommendation
/// engine (web-session based). Embedding the page gives the app exactly the
/// same personalized home feed as the web version. The web session lives in
/// this WebView, so it is owned by the app (unlike the cookies of the external
/// system browser).
final class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends State<HomeScreen> {
  InAppWebViewController? _controller;
  bool _loading = true;
  Object? _error;

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
