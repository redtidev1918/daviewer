import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/downloads/downloads_screen.dart';
import '../features/favourites/favourites_screen.dart';
import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';

final class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          HomeScreen(),
          SearchScreen(),
          FavouritesScreen(),
          DownloadsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            label: 'Favourites',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            label: 'Downloads',
          ),
        ],
      ),
    );
  }
}
