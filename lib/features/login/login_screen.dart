import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/runtime/runtime_provider.dart';

final class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    final auth = ref.watch(authControllerProvider);
    final error = auth.error;

    return Scaffold(
      appBar: AppBar(title: const Text('DA Viewer')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (!runtime.isConfigured) ...[
                const Icon(Icons.vpn_key_off, size: 48),
                const SizedBox(height: 16),
                const Text(
                  '未配置 DAKIT_CLIENT_ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请在 DeviantArt 注册一个 Public OAuth 应用，\n'
                  '并用下面的命令启动：',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const SelectableText(
                    'flutter run -d macos \\\n'
                    '  --dart-define=DAKIT_CLIENT_ID=你的client_id',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'OAuth 回调白名单需精确包含：\ndakit://oauth/callback',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
              ] else ...[
                FilledButton.icon(
                  onPressed: auth.status == AuthStatus.signedIn
                      ? null
                      : () =>
                            ref.read(authControllerProvider.notifier).login(),
                  icon: const Icon(Icons.login),
                  label: const Text('使用 DeviantArt 账号登录'),
                ),
                const SizedBox(height: 8),
                const Text(
                  '将打开浏览器完成授权，登录后返回应用。',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 16),
                SelectableText(
                  '$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
