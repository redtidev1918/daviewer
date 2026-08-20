import 'dart:io';

final class SystemProxyConfig {
  const SystemProxyConfig({required this.host, required this.port});

  final String host;
  final int port;
}

Future<SystemProxyConfig?> detectSystemProxy() async {
  if (!Platform.isMacOS) return null;
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
