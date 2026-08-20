import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'system_proxy.dart';

const _proxyUrl = String.fromEnvironment('DAKIT_PROXY_URL');

final class ProxyController extends ChangeNotifier {
  ProxyController({this.refreshInterval = const Duration(seconds: 15)});

  final Duration refreshInterval;
  Timer? _timer;
  SystemProxyConfig? _config;
  String _directive = 'DIRECT';

  SystemProxyConfig? get config => _config;
  String get directive => _directive;

  Future<void> start() async {
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    final detected =
        await detectSystemProxy() ?? _environmentProxy() ?? _dartDefineProxy();
    if (detected == _config) return;
    _config = detected;
    _directive = detected == null
        ? 'DIRECT'
        : 'PROXY ${detected.host}:${detected.port}';
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static SystemProxyConfig? _dartDefineProxy() {
    if (_proxyUrl.trim().isEmpty) return null;
    return _parseUrl(_proxyUrl.trim());
  }

  static SystemProxyConfig? _environmentProxy() {
    final raw =
        Platform.environment['https_proxy'] ??
        Platform.environment['http_proxy'];
    if (raw == null || raw.trim().isEmpty) return null;
    return _parseUrl(raw.trim());
  }

  static SystemProxyConfig? _parseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) return null;
    return SystemProxyConfig(
      host: uri.host,
      port: uri.hasPort
          ? uri.port
          : uri.scheme == 'https'
          ? 443
          : 80,
    );
  }
}
