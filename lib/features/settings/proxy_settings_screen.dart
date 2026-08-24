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
  bool? _lastTestSucceeded;

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
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Text(
                current == null
                    ? s.proxyCurrentDirect
                    : s.proxyCurrentConfigured(
                        '${current.host}:${current.port}',
                      ),
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
                  hintText: s.proxyAddressExample,
                  helperText: Platform.isAndroid
                      ? s.proxyAddressMobileHelp
                      : s.proxyAddressDesktopHelp,
                  helperMaxLines: 5,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onSubmitted: _busy ? null : (_) => _apply(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _apply,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(s.saveAndTest),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: proxy == null || _busy ? null : _restoreAuto,
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text(s.restoreAutoDetect),
                ),
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  color: _lastTestSucceeded == null
                      ? null
                      : _lastTestSucceeded!
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.errorContainer,
                  child: ListTile(
                    leading: Icon(
                      _lastTestSucceeded == null
                          ? Icons.info_outline
                          : _lastTestSucceeded!
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                    ),
                    title: Text(_status),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
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
              ),
            ],
          ),
        ),
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
    setState(() {
      _busy = true;
      _testingConnection = true;
      _lastTestSucceeded = null;
      _status = s.testingConnection;
    });
    await proxy.setManualProxy(parsed);
    await ref.read(runtimeProvider).webViewProxyManager?.prepare();
    final result = await proxy.testConnection();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testingConnection = false;
      _lastTestSucceeded = result.isSuccess;
      _status = result.isSuccess
          ? s.proxyConnectionReady(parsed.toString())
          : s.savedButTestFailed;
      _controller.text = parsed.toString();
    });
  }

  Future<void> _restoreAuto() async {
    final runtime = ref.read(runtimeProvider);
    final proxy = runtime.proxyController;
    if (proxy == null) return;
    final s = strings(ref.read(appLanguageProvider));
    setState(() {
      _busy = true;
      _testingConnection = true;
      _lastTestSucceeded = null;
      _status = s.testingConnection;
    });
    await proxy.setManualProxy(null);
    await runtime.webViewProxyManager?.prepare();
    final result = await proxy.testConnection();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testingConnection = false;
      _lastTestSucceeded = result.isSuccess;
      _controller.clear();
      _status = result.isSuccess
          ? proxy.config == null
                ? s.directConnectionReady
                : s.proxyConnectionReady(proxy.config.toString())
          : s.connectionNeedsAttention;
    });
  }

  Future<void> _testConnection() async {
    final proxy = ref.read(runtimeProvider).proxyController;
    if (proxy == null) return;
    final s = strings(ref.read(appLanguageProvider));
    setState(() {
      _busy = true;
      _testingConnection = true;
      _lastTestSucceeded = null;
      _status = s.testingConnection;
    });
    final result = await proxy.testConnection();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _testingConnection = false;
      _lastTestSucceeded = result.isSuccess;
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
