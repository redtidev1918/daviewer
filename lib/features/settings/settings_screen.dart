import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/network/system_proxy.dart';
import '../../core/runtime/runtime_provider.dart';

const String _githubUrl = 'https://github.com/redtidev1918/daviewer';
const String versionLabel = '0.2.1';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final account = auth.account;
    final runtime = ref.watch(runtimeProvider);
    final proxy = runtime.proxyController;
    final language = ref.watch(appLanguageProvider);
    final s = strings(language);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(account?.username ?? s.notLoggedIn),
            subtitle: Text(
              auth.status == AuthStatus.signedIn
                  ? (language == AppLanguage.zh
                      ? '已通过 DeviantArt 登录'
                      : 'Signed in with DeviantArt')
                  : (language == AppLanguage.zh
                      ? '登录后可使用关注与收藏功能'
                      : 'Login to use following and favourites'),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: Text(s.favourites),
            onTap: () => context.go('/favourites'),
          ),
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(language == AppLanguage.zh ? '关注用户' : 'Watching'),
            onTap: () => context.push('/watching'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(s.downloads),
            onTap: () => context.go('/downloads'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(s.language),
            subtitle: Text(
              language == AppLanguage.zh ? s.chinese : s.english,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context, ref, language),
          ),
          ListTile(
            leading: const Icon(Icons.lan_outlined),
            title: Text(s.proxy),
            subtitle: Text(
              proxy?.config == null
                  ? (language == AppLanguage.zh ? '未使用代理（直连）' : 'Direct')
                  : '${proxy!.config!.host}:${proxy.config!.port}',
            ),
            onTap: () => context.push('/settings/proxy'),
          ),
          ListTile(
            leading: const Icon(Icons.terminal_outlined),
            title: Text(s.diagnostics),
            subtitle: Text(
              language == AppLanguage.zh ? '查看运行日志与错误记录' : 'View logs',
            ),
            onTap: () => context.push('/settings/diagnostics'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.about),
            subtitle: const Text('DAViewer · $versionLabel'),
            onTap: () => _showAbout(context, language),
          ),
          const Divider(),
          if (auth.status == AuthStatus.signedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(s.logout),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(s.login),
              onTap: () => context.push('/login'),
            ),
        ],
      ),
    );
  }

  void _showLanguagePicker(
    BuildContext context,
    WidgetRef ref,
    AppLanguage current,
  ) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('中文'),
              trailing: current == AppLanguage.zh
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).set(AppLanguage.zh);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('English'),
              trailing: current == AppLanguage.en
                  ? const Icon(Icons.check)
                  : null,
              onTap: () {
                ref.read(appLanguageProvider.notifier).set(AppLanguage.en);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context, AppLanguage language) {
    final isZh = language == AppLanguage.zh;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isZh ? '关于 DAViewer' : 'About DAViewer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('DAViewer v$versionLabel'),
            const SizedBox(height: 8),
            Text(
              isZh
                  ? '一个基于 DAKit 的第三方 DeviantArt 客户端。'
                  : 'A third-party DeviantArt client built on DAKit.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: Text(
                isZh ? 'GitHub 仓库' : 'GitHub repository',
              ),
              subtitle: const Text(
                'github.com/redtidev1918/daviewer',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () async {
                await launchUrl(
                  Uri.parse(_githubUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '关闭' : 'Close'),
          ),
        ],
      ),
    );
  }
}

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
    final proxy = ref.watch(runtimeProvider).proxyController;
    final current = proxy?.config;

    return Scaffold(
      appBar: AppBar(title: const Text('网络代理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            '当前生效：${current == null ? '直连 DIRECT' : 'PROXY ${current.host}:${current.port}'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            '国内访问 DeviantArt 需要代理。应用会自动读取系统代理；'
            '也可以在这里手动指定，例如 127.0.0.1:7890。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: '代理地址 host:port',
              hintText: '127.0.0.1:7890',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton(
                onPressed: _apply,
                child: const Text('应用'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: proxy == null
                    ? null
                    : () {
                        proxy.setManualProxy(null);
                        setState(() => _controller.clear());
                      },
                child: const Text('恢复自动检测'),
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
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      proxy.setManualProxy(null);
      setState(() => _status = '已恢复自动检测');
      return;
    }
    final parts = raw.split(':');
    if (parts.length != 2) {
      setState(() => _status = '格式应为 host:port，例如 127.0.0.1:7890');
      return;
    }
    final port = int.tryParse(parts[1]);
    if (port == null || port <= 0 || port > 65535) {
      setState(() => _status = '端口无效：${parts[1]}');
      return;
    }
    proxy.setManualProxy(SystemProxyConfig(host: parts[0], port: port));
    setState(() => _status = '已应用代理 ${parts[0]}:$port');
  }
}
