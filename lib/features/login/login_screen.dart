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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!runtime.isConfigured)
                const Text('Pass DAKIT_CLIENT_ID at build time.')
              else
                FilledButton(
                  onPressed: auth.status == AuthStatus.signedIn
                      ? null
                      : () => ref.read(authControllerProvider.notifier).login(),
                  child: const Text('Login with DeviantArt'),
                ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text('$error'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
