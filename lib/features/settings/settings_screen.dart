import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';

const String _githubUrl = 'https://github.com/redtidev1918/daviewer';
const String _releasesUrl = 'https://github.com/redtidev1918/daviewer/releases';
const String versionLabel = '0.2.74';

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
    final signedIn = auth.status == AuthStatus.signedIn;

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _AccountHeader(account: account, signedIn: signedIn, s: s),
          const SizedBox(height: 16),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.translate),
                title: Text(s.language),
                subtitle: Text(
                  language == AppLanguage.zh ? s.chinese : s.english,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLanguagePicker(context, ref, language),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lan_outlined),
                title: Text(s.proxy),
                subtitle: Text(
                  proxy?.config == null
                      ? s.directProxy
                      : '${proxy!.config!.host}:${proxy.config!.port}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/proxy'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.terminal_outlined),
                title: Text(s.diagnostics),
                subtitle: Text(s.viewLogs),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/diagnostics'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(s.about),
                subtitle: const Text('DAViewer · $versionLabel'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showAbout(context, s),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SettingsCard(
            children: <Widget>[
              ListTile(
                leading: Icon(signedIn ? Icons.logout : Icons.login),
                title: Text(signedIn ? s.logout : s.login),
                onTap: () {
                  if (signedIn) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(s.signedOut)));
                    ref.read(authControllerProvider.notifier).logout();
                  } else {
                    context.push('/web-login');
                  }
                },
              ),
            ],
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.new_releases_outlined),
              title: Text(s.releases),
              onTap: () async {
                await launchUrl(
                  Uri.parse(_releasesUrl),
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

/// A rounded card holding a related group of [ListTile]s.
final class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// The account header: avatar, username, and sign-in state.
final class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.account,
    required this.signedIn,
    required this.s,
  });

  final UserProfile? account;
  final bool signedIn;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final username = account?.username ?? '';
    final uri = account?.avatarUri?.toString();
    final fallback = CircleAvatar(
      radius: 28,
      child: Text(username.isEmpty ? '?' : username[0].toUpperCase()),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            if (uri == null || uri.isEmpty)
              fallback
            else
              CachedNetworkImage(
                imageUrl: uri,
                memCacheWidth: 120,
                imageBuilder: (context, imageProvider) =>
                    CircleAvatar(radius: 28, backgroundImage: imageProvider),
                placeholder: (context, url) => fallback,
                errorWidget: (context, url, error) => fallback,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    username.isEmpty ? s.notLoggedIn : username,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signedIn ? s.signedInWithDA : s.loginHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
