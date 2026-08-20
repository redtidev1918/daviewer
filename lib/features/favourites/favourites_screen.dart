import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';
import '../../shared/widgets/artwork_card.dart';
import 'favourites_providers.dart';

final class FavouritesScreen extends ConsumerWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.status != AuthStatus.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favourites')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Login with DeviantArt'),
          ),
        ),
      );
    }

    final favourites = ref.watch(currentFavouritesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Favourites')),
      body: favourites.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('$error')),
        data: (artworks) => artworks.isEmpty
            ? const Center(child: Text('No favourites found.'))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
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
