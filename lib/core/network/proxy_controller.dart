import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../diagnostics/app_logger.dart';
import 'system_proxy.dart';

const _proxyUrl = String.fromEnvironment('DAKIT_PROXY_URL');

/// Detects the effective outbound proxy for the app and exposes it as a
/// `findProxy`-style directive.
///
/// Priority (highest first):
/// 1. Manual override set at runtime (e.g. from Settings).
/// 2. OS system proxy (macOS `scutil`, Windows registry).
/// 3. Standard proxy environment variables (lowercase and uppercase,
///    including `all_proxy` / `ALL_PROXY`).
/// 4. Compile-time `--dart-define=DAKIT_PROXY_URL=...`.
final class ProxyController extends ChangeNotifier {
  ProxyController({this.refreshInterval = const Duration(seconds: 15)});

  final Duration refreshInterval;
  Timer? _timer;
  SystemProxyConfig? _config;
  SystemProxyConfig? _manual;
  String _directive = 'DIRECT';
  bool _isUsingSystemProxy = true;

  /// Effective proxy configuration, or null when going direct.
  SystemProxyConfig? get config => _config;

  /// `PROXY host:port` or `DIRECT`, consumable by `HttpClient.findProxy`.
  String get directive => _directive;

  /// Whether the current config came from the OS (vs manual/environment).
  bool get isUsingSystemProxy => _isUsingSystemProxy;

  /// The proxy chosen manually by the user, if any.
  SystemProxyConfig? get manualOverride => _manual;

  Future<void> start() async {
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  /// Sets a manual proxy override. Pass `null` to clear it and fall back to
  /// automatic detection.
  void setManualProxy(SystemProxyConfig? proxy) {
    _manual = proxy;
    _isUsingSystemProxy = false;
    AppLogger.instance.info(
      'proxy',
      proxy == null ? 'manual proxy cleared' : 'manual proxy $proxy',
    );
    _recompute();
  }

  Future<void> refresh() async {
    final detected = _manual ?? await _detectAutomatic();
    if (detected == _config) return;
    _config = detected;
    _recompute();
  }

  Future<SystemProxyConfig?> _detectAutomatic() async {
    final system = await detectSystemProxy();
    if (system != null) {
      _isUsingSystemProxy = true;
      return system;
    }
    _isUsingSystemProxy = false;
    return _environmentProxy() ?? _dartDefineProxy();
  }

  void _recompute() {
    final detected = _config;
    _directive = detected == null
        ? 'DIRECT'
        : 'PROXY ${detected.host}:${detected.port}';
    AppLogger.instance.info(
      'proxy',
      'effective proxy: $_directive (manual=$_manual, '
          'system=$_isUsingSystemProxy)',
    );
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
        Platform.environment['HTTPS_PROXY'] ??
        Platform.environment['http_proxy'] ??
        Platform.environment['HTTP_PROXY'] ??
        Platform.environment['all_proxy'] ??
        Platform.environment['ALL_PROXY'];
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
