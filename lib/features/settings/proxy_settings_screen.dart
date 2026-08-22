import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/system_proxy.dart';
import '../../core/runtime/runtime_provider.dart';

/// Lets the user inspect or override the effective proxy for this session.
final class ProxySettingsScreen extends ConsumerStatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  ConsumerState<ProxySettingsScreen> createState() =>
      _ProxySettingsScreenState();
}

final class _ProxySettingsScreenState
    extends ConsumerState<ProxySettingsScreen> {
  final _controller = TextEditingController();
  String _status = '';

  @override
  void initState() {
    super.initState();
    final manual = ref.read(runtimeProvider).proxyController?.manualOverride;
    _controller.text = manual == null ? '' : '${manual.host}:${manual.port}';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final proxy = ref.watch(runtimeProvider).proxyController;
    final current = proxy?.config;

    return Scaffold(
      appBar: AppBar(title: Text(s.proxy)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            current == null
                ? s.proxyCurrentDirect
                : s.proxyCurrentConfigured('${current.host}:${current.port}'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(s.proxyHint, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: s.proxyAddressLabel,
              hintText: '127.0.0.1:7890',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton(onPressed: _apply, child: Text(s.apply)),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: proxy == null
                    ? null
                    : () {
                        proxy.setManualProxy(null);
                        setState(() => _controller.clear());
                      },
                child: Text(s.restoreAutoDetect),
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  void _apply() {
    final proxy = ref.read(runtimeProvider).proxyController;
    if (proxy == null) return;
    final s = strings(ref.read(appLanguageProvider));
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      proxy.setManualProxy(null);
      setState(() => _status = s.restoredAutoDetect);
      return;
    }
    final parts = raw.split(':');
    if (parts.length != 2) {
      setState(() => _status = s.invalidProxyFormat);
      return;
    }
    final port = int.tryParse(parts[1]);
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _status = s.invalidProxyPort(parts[1]));
      return;
    }
    proxy.setManualProxy(SystemProxyConfig(host: parts[0], port: port));
    setState(() => _status = s.appliedProxy('${parts[0]}:$port'));
  }
}
