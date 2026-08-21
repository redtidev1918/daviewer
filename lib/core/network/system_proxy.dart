import 'dart:io';

import '../diagnostics/app_logger.dart';

final class SystemProxyConfig {
  const SystemProxyConfig({required this.host, required this.port});

  final String host;
  final int port;

  @override
  bool operator ==(Object other) =>
      other is SystemProxyConfig && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$host:$port';
}

Future<SystemProxyConfig?> detectSystemProxy() async {
  final logger = AppLogger.instance;
  if (Platform.isMacOS) return _detectMacOsProxy(logger);
  if (Platform.isWindows) return _detectWindowsProxy(logger);
  if (Platform.isLinux) return _detectLinuxProxy(logger);
  return null;
}

Future<SystemProxyConfig?> _detectMacOsProxy(AppLogger logger) async {
  try {
    final result = await Process.run('scutil', const <String>['--proxy']);
    final output = (result.stdout as String? ?? '').split('\n');
    final values = <String, String>{};
    for (final line in output) {
      final separator = line.indexOf(':');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) values[key] = value;
    }

    // macOS can expose HTTP and HTTPS proxies independently; prefer HTTPS.
    final httpsEnabled = values['HTTPSEnable'] == '1';
    final httpEnabled = values['HTTPEnable'] == '1';
    final host = httpsEnabled
        ? values['HTTPSProxy']
        : httpEnabled
        ? values['HTTPProxy']
        : null;
    if (host == null || host.isEmpty) {
      logger.info('proxy', 'macOS: no static proxy configured');
      return null;
    }

    final port = int.tryParse(
      httpsEnabled ? values['HTTPSPort'] ?? '' : values['HTTPPort'] ?? '',
    );
    if (port == null || port <= 0 || port > 65535) {
      logger.warning('proxy', 'macOS: invalid proxy port, ignoring');
      return null;
    }
    logger.info('proxy', 'macOS: detected $host:$port');
    return SystemProxyConfig(host: host, port: port);
  } on Object catch (error, stack) {
    logger.warning('proxy', 'macOS proxy detection failed', error, stack);
    return null;
  }
}

Future<SystemProxyConfig?> _detectWindowsProxy(AppLogger logger) async {
  try {
    final enabledResult = await Process.run('reg', const <String>[
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
    ]);
    final enabledOutput = enabledResult.stdout as String? ?? '';
    if (!enabledOutput.contains('0x1')) {
      logger.info('proxy', 'Windows: proxy disabled');
      return null;
    }

    final serverResult = await Process.run('reg', const <String>[
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyServer',
    ]);
    final serverOutput = serverResult.stdout as String? ?? '';
    final match = RegExp(r'ProxyServer\s+REG_SZ\s+([^\r\n]+)')
        .firstMatch(serverOutput);
    final server = match?.group(1)?.trim();
    if (server == null || server.isEmpty) {
      logger.info('proxy', 'Windows: no proxy server value');
      return null;
    }

    final hostAndPort = server.split(':');
    final host = hostAndPort.first;
    final port = hostAndPort.length > 1 ? int.tryParse(hostAndPort[1]) : 8080;
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      logger.warning('proxy', 'Windows: invalid proxy server "$server"');
      return null;
    }
    logger.info('proxy', 'Windows: detected $host:$port');
    return SystemProxyConfig(host: host, port: port);
  } on Object catch (error, stack) {
    logger.warning('proxy', 'Windows proxy detection failed', error, stack);
    return null;
  }
}

Future<SystemProxyConfig?> _detectLinuxProxy(AppLogger logger) async {
  try {
    final result = await Process.run('gsettings', const <String>[
      'get',
      'org.gnome.system.proxy.http',
      'host',
    ]);
    final host = (result.stdout as String? ?? '').trim().replaceAll("'", '');
    if (host.isEmpty || host == '""') {
      logger.info('proxy', 'Linux: no gsettings proxy');
      return null;
    }
    final portResult = await Process.run('gsettings', const <String>[
      'get',
      'org.gnome.system.proxy.http',
      'port',
    ]);
    final port = int.tryParse((portResult.stdout as String? ?? '').trim());
    if (port == null || port <= 0 || port > 65535) {
      logger.warning('proxy', 'Linux: invalid proxy port');
      return null;
    }
    logger.info('proxy', 'Linux: detected $host:$port');
    return SystemProxyConfig(host: host, port: port);
  } on Object catch (error, stack) {
    logger.warning('proxy', 'Linux proxy detection failed', error, stack);
    return null;
  }
}
