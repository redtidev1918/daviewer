import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' as webview;

import '../diagnostics/app_logger.dart';
import 'proxy_controller.dart';
import 'system_proxy.dart';

enum WebViewProxyState { system, applied, unsupported, failed, direct }

/// Keeps browser traffic on the same network path as API and download traffic.
///
/// Android supports a process-wide WebView proxy override. Windows requires a
/// WebView2 environment created with browser arguments. macOS uses a small
/// native bridge backed by WKWebsiteDataStore on macOS 14 and later; older
/// versions can still use the OS system proxy.
final class WebViewProxyManager {
  WebViewProxyManager(this._proxyController);

  static const MethodChannel _macChannel = MethodChannel(
    'daviewer/webview_proxy',
  );

  final ProxyController _proxyController;
  webview.WebViewEnvironment? _windowsEnvironment;
  SystemProxyConfig? _windowsConfig;
  WebViewProxyState _state = WebViewProxyState.direct;
  Future<void>? _preparing;

  webview.WebViewEnvironment? get environment => _windowsEnvironment;

  webview.CookieManager get cookieManager => webview.CookieManager.instance(
    webViewEnvironment: Platform.isWindows ? _windowsEnvironment : null,
  );

  WebViewProxyState get state => _state;

  Future<webview.WebViewEnvironment?> prepare() async {
    final active = _preparing;
    if (active != null) {
      await active;
      return prepare();
    }
    final completion = Completer<void>();
    _preparing = completion.future;
    try {
      return await _prepareNow();
    } finally {
      completion.complete();
      if (identical(_preparing, completion.future)) _preparing = null;
    }
  }

  Future<webview.WebViewEnvironment?> _prepareNow() async {
    final proxy = _proxyController.config;
    try {
      if (Platform.isWindows) {
        await _prepareWindows(proxy);
      } else if (Platform.isAndroid) {
        await _prepareAndroid(proxy);
      } else if (Platform.isMacOS) {
        await _prepareMacOS(proxy);
      } else {
        _state = proxy == null
            ? WebViewProxyState.direct
            : _proxyController.source == ProxySource.system
            ? WebViewProxyState.system
            : WebViewProxyState.unsupported;
      }
    } on Object catch (error, stack) {
      _state = WebViewProxyState.failed;
      AppLogger.instance.warning(
        'webview-proxy',
        'failed to prepare WebView proxy',
        error,
        stack,
      );
    }
    return _windowsEnvironment;
  }

  Future<void> _prepareAndroid(SystemProxyConfig? proxy) async {
    final controller = webview.ProxyController.instance();
    if (proxy == null || _proxyController.source == ProxySource.system) {
      await controller.clearProxyOverride();
      _state = proxy == null
          ? WebViewProxyState.direct
          : WebViewProxyState.system;
      return;
    }
    await controller.setProxyOverride(
      settings: webview.ProxySettings(
        proxyRules: <webview.ProxyRule>[
          webview.ProxyRule(url: 'http://${proxy.host}:${proxy.port}'),
        ],
      ),
    );
    _state = WebViewProxyState.applied;
  }

  Future<void> _prepareMacOS(SystemProxyConfig? proxy) async {
    if (proxy == null || _proxyController.source == ProxySource.system) {
      final supported = await _macChannel.invokeMethod<bool>('clearProxy');
      _state = proxy == null
          ? WebViewProxyState.direct
          : WebViewProxyState.system;
      AppLogger.instance.info(
        'webview-proxy',
        'macOS native proxy bridge supported=${supported ?? false}',
      );
      return;
    }
    final supported = await _macChannel.invokeMethod<bool>('setProxy', {
      'host': proxy.host,
      'port': proxy.port,
    });
    _state = supported == true
        ? WebViewProxyState.applied
        : WebViewProxyState.unsupported;
  }

  Future<void> _prepareWindows(SystemProxyConfig? proxy) async {
    if (_windowsEnvironment != null && proxy == _windowsConfig) {
      _state = proxy == null
          ? WebViewProxyState.direct
          : WebViewProxyState.applied;
      return;
    }
    final previous = _windowsEnvironment;
    _windowsEnvironment = null;
    _windowsConfig = proxy;
    if (previous != null) await previous.dispose();
    _windowsEnvironment = await webview.WebViewEnvironment.create(
      settings: webview.WebViewEnvironmentSettings(
        additionalBrowserArguments: proxy == null
            ? null
            : '--proxy-server=http://${proxy.host}:${proxy.port}',
      ),
    );
    _state = proxy == null
        ? WebViewProxyState.direct
        : WebViewProxyState.applied;
  }

  Future<void> dispose() async {
    final environment = _windowsEnvironment;
    _windowsEnvironment = null;
    if (environment != null) await environment.dispose();
  }
}
