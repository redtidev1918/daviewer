import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/artwork_card.dart';
import 'home_providers.dart';

final class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    final auth = ref.watch(authControllerProvider);
    final feed = ref.watch(homeFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DA Viewer'),
        actions: <Widget>[
          if (auth.status == AuthStatus.signedOut)
            IconButton(
              tooltip: 'Login',
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login),
            )
          else if (auth.status == AuthStatus.signedIn)
            IconButton(
              tooltip: 'Logout',
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: !runtime.isConfigured
          ? const Center(child: Text('Pass DAKIT_CLIENT_ID at build time.'))
          : feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('$error')),
              data: (artworks) => artworks.isEmpty
                  ? const Center(child: Text('No artworks found.'))
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 260,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                      itemCount: artworks.length,
                      itemBuilder: (context, index) {
                        final artwork = artworks[index];
                        return ArtworkCard(
                          artwork: artwork,
                          onTap: () => context.go('/artwork/${artwork.id}'),
                        );
                      },
                    ),
            ),
    );
  }
}
