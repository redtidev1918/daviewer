import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';

final artistProfileProvider = FutureProvider.autoDispose
    .family<UserProfileDetails, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      return OfficialUserRepository(transport).profile(username);
    });

final artistGalleryProvider = FutureProvider.autoDispose
    .family<List<Artwork>, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      final page = await OfficialGalleryRepository(transport)
          .gallery(username, const PageRequest(limit: 24));
      return page.items;
    });

final artistFavouritesProvider = FutureProvider.autoDispose
    .family<List<Artwork>, String>((ref, username) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      final page = await OfficialGalleryRepository(transport)
          .favourites(username, const PageRequest(limit: 24));
      return page.items;
    });
