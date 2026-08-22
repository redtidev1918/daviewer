import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';

const String _githubUrl = 'https://github.com/redtidev1918/daviewer';
const String versionLabel = '0.2.50';

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
                  ? s.signedInWithDA
                  : s.loginHint,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(s.language),
            subtitle: Text(language == AppLanguage.zh ? s.chinese : s.english),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguagePicker(context, ref, language),
          ),
          ListTile(
            leading: const Icon(Icons.lan_outlined),
            title: Text(s.proxy),
            subtitle: Text(
              proxy?.config == null
                  ? s.directProxy
                  : '${proxy!.config!.host}:${proxy.config!.port}',
            ),
            onTap: () => context.push('/settings/proxy'),
          ),
          ListTile(
            leading: const Icon(Icons.terminal_outlined),
            title: Text(s.diagnostics),
            subtitle: Text(s.viewLogs),
            onTap: () => context.push('/settings/diagnostics'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(s.about),
            subtitle: const Text('DAViewer · $versionLabel'),
            onTap: () => _showAbout(context, s),
          ),
          const Divider(),
          if (auth.status == AuthStatus.signedIn) ...[
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(s.logout),
              onTap: () {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(s.signedOut)));
                ref.read(authControllerProvider.notifier).logout();
              },
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(s.login),
              onTap: () => context.push('/web-login'),
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

  void _showAbout(BuildContext context, AppStrings s) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.aboutDAViewer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('DAViewer v$versionLabel'),
            const SizedBox(height: 8),
            Text(s.aboutDescription),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.code),
              title: Text(s.githubRepository),
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
            child: Text(s.close),
          ),
        ],
      ),
    );
  }
}
