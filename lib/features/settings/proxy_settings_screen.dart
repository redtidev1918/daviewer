import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/network/proxy_controller.dart';
import '../../core/network/webview_proxy_manager.dart';
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
  bool _busy = false;
  bool _testingConnection = false;

  @override
  void initState() {
    super.initState();
    final manual = ref.read(runtimeProvider).proxyController?.manualOverride;
    _controller.text = manual == null ? '' : '${manual.host}:${manual.port}';
    ref.read(runtimeProvider).proxyController?.addListener(_onProxyChanged);
  }

  @override
  void dispose() {
    ref.read(runtimeProvider).proxyController?.removeListener(_onProxyChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onProxyChanged() {
    if (mounted) setState(() {});
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
          Text(_sourceLabel(proxy?.source, s)),
          const SizedBox(height: 4),
          Text(s.proxyHint, style: Theme.of(context).textTheme.bodySmall),
          if (Platform.isMacOS &&
              proxy?.manualOverride != null &&
              ref.watch(runtimeProvider).webViewProxyManager?.state ==
                  WebViewProxyState.unsupported) ...[
            const SizedBox(height: 8),
            Text(
              s.proxyMacLegacyHint,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: s.proxyAddressLabel,
              hintText: 'http://127.0.0.1:7892',
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: _busy ? null : _apply,
                child: Text(s.apply),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: proxy == null || _busy ? null : _restoreAuto,
                child: Text(s.restoreAutoDetect),
              ),
            ],
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(_status, style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: proxy == null || _busy ? null : _testConnection,
            icon: _testingConnection
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.network_check),
            label: Text(
              _testingConnection ? s.testingConnection : s.testConnection,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _apply() async {
    final proxy = ref.read(runtimeProvider).proxyController;
    if (proxy == null) return;
    final s = strings(ref.read(appLanguageProvider));
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      await _restoreAuto();
      return;
    }
    final parsed = parseProxyAddress(raw);
    if (parsed == null) {
      setState(() => _status = s.invalidProxyFormat);
      return;
    }
    setState(() => _busy = true);
    await proxy.setManualProxy(parsed);
    await ref.read(runtimeProvider).webViewProxyManager?.prepare();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = s.appliedProxy(parsed.toString());
      _controller.text = parsed.toString();
    });
  }

  Future<void> _restoreAuto() async {
    final runtime = ref.read(runtimeProvider);
    final proxy = runtime.proxyController;
    if (proxy == null) return;
    setState(() => _busy = true);
    await proxy.setManualProxy(null);
    await runtime.webViewProxyManager?.prepare();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _controller.clear();
      _status = strings(ref.read(appLanguageProvider)).restoredAutoDetect;
    });
  }

  Future<void> _testConnection() async {
    final proxy = ref.read(runtimeProvider).proxyController;
    if (proxy == null) return;
    final s = strings(ref.read(appLanguageProvider));
    setState(() {
      _busy = true;
      _testingConnection = true;
      _status = s.testingConnection;
    });
    final result = await proxy.testConnection();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testingConnection = false;
      _status = result.isSuccess
          ? s.proxyTestSucceeded(result.elapsed.inMilliseconds)
          : s.proxyTestFailed;
    });
  }

  String _sourceLabel(ProxySource? source, AppStrings s) => switch (source) {
    ProxySource.manual => s.proxySourceManual,
    ProxySource.system => s.proxySourceSystem,
    ProxySource.environment => s.proxySourceEnvironment,
    ProxySource.dartDefine => s.proxySourceBuild,
    ProxySource.direct || null => s.proxySourceDirect,
  };
}
