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
              const Icon(Icons.login, size: 48),
              const SizedBox(height: 16),
              const Text(
                '登录 DeviantArt',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '使用你的 DeviantArt 账号登录，'
                '浏览作品、收藏、关注作者并下载原图。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: auth.status == AuthStatus.signedIn || !runtime.isConfigured
                    ? null
                    : () => ref.read(authControllerProvider.notifier).login(),
                icon: const Icon(Icons.login),
                label: const Text('使用 DeviantArt 账号登录'),
              ),
              const SizedBox(height: 8),
              const Text(
                '将打开系统浏览器完成授权，登录后自动返回应用。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
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
