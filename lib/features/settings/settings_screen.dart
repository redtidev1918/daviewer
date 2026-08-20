import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';

final class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final account = auth.account;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.account_circle_outlined),
            title: Text(account?.username ?? 'Not signed in'),
            subtitle: Text(
              auth.status == AuthStatus.signedIn
                  ? 'Signed in with DeviantArt'
                  : 'Login required for following and favourites',
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.favorite_outline),
            title: const Text('Favourites'),
            onTap: () => context.go('/favourites'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Downloads'),
            onTap: () => context.go('/downloads'),
          ),
          const Divider(),
          if (auth.status == AuthStatus.signedIn)
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            )
          else
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Login with DeviantArt'),
              onTap: () => context.push('/login'),
            ),
        ],
      ),
    );
  }
}
