import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../diagnostics/app_logger.dart';
import '../settings/app_preferences.dart';
import 'system_proxy.dart';

const _proxyUrl = String.fromEnvironment('DAKIT_PROXY_URL');

enum ProxySource { manual, system, environment, dartDefine, direct }

final class ProxyCheckResult {
  const ProxyCheckResult({
    required this.isSuccess,
    required this.elapsed,
    this.statusCode,
  });

  final bool isSuccess;
  final Duration elapsed;
  final int? statusCode;
}

SystemProxyConfig? parseProxyAddress(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw.contains('://') ? raw : 'http://$raw');
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  // dart:io's PAC directive supports an HTTP CONNECT proxy (`PROXY`), not a
  // TLS-to-proxy or SOCKS transport. Reject those schemes instead of silently
  // claiming that the whole app is routed when only some clients might work.
  if (uri.scheme != 'http') return null;
  final port = uri.hasPort ? uri.port : 80;
  if (port <= 0 || port > 65535) return null;
  return SystemProxyConfig(host: uri.host, port: port);
}

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
  ProxySource _source = ProxySource.direct;

  /// Effective proxy configuration, or null when going direct.
  SystemProxyConfig? get config => _config;

  /// `PROXY host:port` or `DIRECT`, consumable by `HttpClient.findProxy`.
  String get directive => _directive;

  /// Whether the current config came from the OS (vs manual/environment).
  bool get isUsingSystemProxy => _isUsingSystemProxy;

  ProxySource get source => _source;

  /// The proxy chosen manually by the user, if any.
  SystemProxyConfig? get manualOverride => _manual;

  Future<void> start() async {
    final persisted = await AppPreferences.loadManualProxy();
    if (persisted != null) {
      _manual = parseProxyAddress(persisted);
      if (_manual == null) {
        await AppPreferences.saveManualProxy(null);
        AppLogger.instance.warning('proxy', 'discarded invalid saved proxy');
      }
    }
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  /// Sets a manual proxy override. Pass `null` to clear it and fall back to
  /// automatic detection.
  Future<void> setManualProxy(SystemProxyConfig? proxy) async {
    _manual = proxy;
    await AppPreferences.saveManualProxy(proxy?.toString());
    AppLogger.instance.info(
      'proxy',
      proxy == null ? 'manual proxy cleared' : 'manual proxy $proxy',
    );
    await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    final (detected, source) = _manual == null
        ? await _detectAutomatic()
        : (_manual, ProxySource.manual);
    if (!force && detected == _config && source == _source) return;
    _config = detected;
    _source = source;
    _isUsingSystemProxy = source == ProxySource.system;
    _recompute();
  }

  Future<(SystemProxyConfig?, ProxySource)> _detectAutomatic() async {
    final system = await detectSystemProxy();
    if (system != null) {
      return (system, ProxySource.system);
    }
    final environment = _environmentProxy();
    if (environment != null) {
      return (environment, ProxySource.environment);
    }
    final dartDefine = _dartDefineProxy();
    return (
      dartDefine,
      dartDefine == null ? ProxySource.direct : ProxySource.dartDefine,
    );
  }

  Future<ProxyCheckResult> testConnection() async {
    final stopwatch = Stopwatch()..start();
    final client = HttpClient()..findProxy = (_) => directive;
    try {
      final request = await client
          .getUrl(Uri.parse('https://www.deviantart.com/'))
          .timeout(const Duration(seconds: 12));
      request.headers.set(HttpHeaders.userAgentHeader, 'DAViewer/1.0');
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      await response.drain<void>().timeout(const Duration(seconds: 12));
      stopwatch.stop();
      final success = response.statusCode >= 200 && response.statusCode < 400;
      AppLogger.instance.info(
        'proxy',
        'connectivity check: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms',
      );
      return ProxyCheckResult(
        isSuccess: success,
        elapsed: stopwatch.elapsed,
        statusCode: response.statusCode,
      );
    } on Object catch (error, stack) {
      stopwatch.stop();
      AppLogger.instance.warning(
        'proxy',
        'connectivity check failed after ${stopwatch.elapsedMilliseconds}ms',
        error,
        stack,
      );
      return ProxyCheckResult(isSuccess: false, elapsed: stopwatch.elapsed);
    } finally {
      client.close(force: true);
    }
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
    return parseProxyAddress(_proxyUrl.trim());
  }

  static SystemProxyConfig? _environmentProxy() {
    for (final name in const <String>[
      'https_proxy',
      'HTTPS_PROXY',
      'http_proxy',
      'HTTP_PROXY',
      'all_proxy',
      'ALL_PROXY',
    ]) {
      final raw = Platform.environment[name];
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = parseProxyAddress(raw);
      if (parsed != null) return parsed;
      AppLogger.instance.warning(
        'proxy',
        'ignored unsupported $name proxy scheme',
      );
    }
    return null;
  }
}
