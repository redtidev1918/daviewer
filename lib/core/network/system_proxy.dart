import 'dart:io';

final class SystemProxyConfig {
  const SystemProxyConfig({required this.host, required this.port});

  final String host;
  final int port;
}

Future<SystemProxyConfig?> detectSystemProxy() async {
  if (Platform.isMacOS) return _detectMacOsProxy();
  if (Platform.isWindows) return _detectWindowsProxy();
  return null;
}

Future<SystemProxyConfig?> _detectMacOsProxy() async {
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

    final httpsEnabled = values['HTTPSEnable'] == '1';
    final httpEnabled = values['HTTPEnable'] == '1';
    final httpsHost = values['HTTPSProxy'];
    final httpHost = values['HTTPProxy'];
    final host = httpsEnabled
        ? httpsHost
        : httpEnabled
        ? httpHost
        : null;
    if (host == null || host.isEmpty) return null;

    final port = int.tryParse(
      httpsEnabled ? values['HTTPSPort'] ?? '' : values['HTTPPort'] ?? '',
    );
    if (port == null || port <= 0 || port > 65535) return null;
    return SystemProxyConfig(host: host, port: port);
  } on Object {
    return null;
  }
}

Future<SystemProxyConfig?> _detectWindowsProxy() async {
  try {
    final enabledResult = await Process.run('reg', const <String>[
      'query',
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings',
      '/v',
      'ProxyEnable',
    ]);
    final enabledOutput = enabledResult.stdout as String? ?? '';
    if (!enabledOutput.contains('0x1')) return null;

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
    if (server == null || server.isEmpty) return null;

    final hostAndPort = server.split(':');
    final host = hostAndPort.first;
    final port = hostAndPort.length > 1 ? int.tryParse(hostAndPort[1]) : 8080;
    if (host.isEmpty || port == null || port <= 0 || port > 65535) {
      return null;
    }
    return SystemProxyConfig(host: host, port: port);
  } on Object {
    return null;
  }
}
