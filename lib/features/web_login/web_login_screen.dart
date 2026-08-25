import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/proxy_controller.dart' as app_proxy;
import '../../core/runtime/runtime_provider.dart';

bool systemBrowserFollowsSelectedProxy(app_proxy.ProxySource source) =>
    source == app_proxy.ProxySource.system ||
    source == app_proxy.ProxySource.direct;

/// Any HTTP response proves that the app network route reached DeviantArt.
/// A 403/429/503 may be an interactive provider check and must not be reported
/// as a broken proxy merely because it is not a 2xx response.
bool loginRouteReachedProvider(int? statusCode) =>
    statusCode != null && statusCode >= 100 && statusCode <= 599;

final class WebLoginScreen extends ConsumerStatefulWidget {
  const WebLoginScreen({super.key});

  @override
  ConsumerState<WebLoginScreen> createState() => _WebLoginScreenState();
}

final class _WebLoginScreenState extends ConsumerState<WebLoginScreen> {
  static final Uri _homeUri = Uri.parse('https://www.deviantart.com/');
  static final Uri _forgotUri = Uri.parse(
    'https://www.deviantart.com/users/forgot',
  );
  static final Uri _contentSettingsUri = Uri.parse(
    'https://www.deviantart.com/settings/browsing',
  );

  Timer? _delayTimer;
  bool _waiting = false;
  bool _delayed = false;
  bool _testingNetwork = false;
  bool? _networkReachable;
  String _networkStatus = '';
  bool _completed = false;

  @override
  void dispose() {
    _delayTimer?.cancel();
    ref.read(runtimeProvider).oauthLauncher?.finish();
    if (_waiting && !_completed) {
      unawaited(ref.read(authControllerProvider.notifier).cancelLogin());
    }
    super.dispose();
  }

  Future<void> _startLogin() async {
    if (_waiting) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (ref.read(authControllerProvider).oauthSignedIn) {
      if (mounted) context.pop();
      return;
    }
    setState(() {
      _waiting = true;
      _delayed = false;
    });
    _delayTimer?.cancel();
    _delayTimer = Timer(const Duration(seconds: 90), () {
      if (mounted && _waiting) setState(() => _delayed = true);
    });
    await controller.login();
    _delayTimer?.cancel();
    ref.read(runtimeProvider).oauthLauncher?.finish();
    if (!mounted) return;
    if (ref.read(authControllerProvider).oauthSignedIn) {
      _completed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings(ref.read(appLanguageProvider)).loginSuccess),
        ),
      );
      context.pop();
      return;
    }
    setState(() => _waiting = false);
  }

  Future<void> _cancelLogin() async {
    _delayTimer?.cancel();
    ref.read(runtimeProvider).oauthLauncher?.finish();
    await ref.read(authControllerProvider.notifier).cancelLogin();
    if (mounted) {
      setState(() {
        _waiting = false;
        _delayed = false;
      });
    }
  }

  Future<void> _reopenLogin() async {
    await ref.read(runtimeProvider).oauthLauncher?.reopen();
  }

  Future<void> _testNetwork() async {
    if (_testingNetwork) return;
    final s = strings(ref.read(appLanguageProvider));
    final dio = ref.read(runtimeProvider).dio;
    if (dio == null) return;
    setState(() {
      _testingNetwork = true;
      _networkStatus = s.testingConnection;
    });
    final watch = Stopwatch()..start();
    try {
      final response = await dio
          .get<String>(
            _homeUri.toString(),
            options: Options(
              responseType: ResponseType.plain,
              validateStatus: (_) => true,
            ),
          )
          .timeout(const Duration(seconds: 15));
      watch.stop();
      final reached = loginRouteReachedProvider(response.statusCode);
      if (!mounted) return;
      setState(() {
        _networkReachable = reached;
        _networkStatus = reached
            ? s.proxyTestSucceeded(watch.elapsedMilliseconds)
            : s.proxyTestFailed;
      });
    } on Object {
      watch.stop();
      if (!mounted) return;
      setState(() {
        _networkReachable = false;
        _networkStatus = s.proxyTestFailed;
      });
    } finally {
      if (mounted) setState(() => _testingNetwork = false);
    }
  }

  Future<void> _leave() async {
    if (_waiting) await _cancelLogin();
    if (mounted) context.pop();
  }

  void _showHelp() {
    final s = strings(ref.read(appLanguageProvider));
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.loginHelpTitle),
        content: SingleChildScrollView(child: Text(s.loginHelpBody)),
        actions: <Widget>[
          TextButton(
            onPressed: () =>
                launchUrl(_forgotUri, mode: LaunchMode.externalApplication),
            child: Text(s.forgotPassword),
          ),
          TextButton(
            onPressed: () => launchUrl(
              _contentSettingsUri,
              mode: LaunchMode.externalApplication,
            ),
            child: Text(s.contentSettings),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.close),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);
    final runtime = ref.watch(runtimeProvider);
    final proxy = runtime.proxyController;
    final config = proxy?.config;
    final currentProxy = config == null
        ? s.proxyCurrentDirect
        : s.proxyCurrentConfigured(config.toString());
    final proxySource = proxy?.source ?? app_proxy.ProxySource.direct;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.signInWelcomeTitle),
        actions: <Widget>[
          IconButton(
            tooltip: s.settings,
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: s.loginHelpTooltip,
            onPressed: _showHelp,
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            tooltip: s.close,
            onPressed: _leave,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              children: <Widget>[
                Align(
                  child: CircleAvatar(
                    radius: 34,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.palette_outlined,
                      size: 36,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  s.signInWelcomeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  s.signInWelcomeBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: _waiting ? null : _startLogin,
                  icon: _waiting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_browser),
                  label: Text(s.signInOrRegister),
                ),
                const SizedBox(height: 8),
                Text(
                  s.singleSignInDescription,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                if (_waiting) ...[
                  const SizedBox(height: 16),
                  Card(
                    color: theme.colorScheme.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: <Widget>[
                          Text(
                            _delayed
                                ? s.externalBrowserDelayed
                                : s.externalBrowserWaiting,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: _reopenLogin,
                                icon: const Icon(Icons.open_in_browser),
                                label: Text(s.reopenBrowser),
                              ),
                              TextButton.icon(
                                onPressed: _cancelLogin,
                                icon: const Icon(Icons.close),
                                label: Text(s.cancel),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (auth.error case final error?) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.error_outline),
                      title: Text(s.loginFailed(friendlyErrorMessage(error))),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Card(
                  color: _networkReachable == null
                      ? null
                      : _networkReachable!
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              _networkReachable == null
                                  ? Icons.lan_outlined
                                  : _networkReachable!
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_off_outlined,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.networkBeforeLogin,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(s.loginNetworkHint),
                        if (!systemBrowserFollowsSelectedProxy(
                          proxySource,
                        )) ...[
                          const SizedBox(height: 8),
                          Text(
                            s.externalBrowserProxyHint,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          currentProxy,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_networkStatus.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _networkStatus,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              await context.push('/settings/proxy');
                              if (mounted) unawaited(_testNetwork());
                            },
                            icon: const Icon(Icons.settings_ethernet),
                            label: Text(s.proxy),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _testingNetwork ? null : _testNetwork,
                            icon: _testingNetwork
                                ? const SizedBox.square(
                                    dimension: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.network_check),
                            label: Text(s.testConnection),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
