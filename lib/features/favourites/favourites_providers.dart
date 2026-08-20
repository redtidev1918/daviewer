import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/runtime/runtime_provider.dart';

final currentFavouritesProvider = FutureProvider.autoDispose<List<Artwork>>((
  ref,
) async {
  final account = ref.watch(authControllerProvider).account;
  if (account == null) {
    throw Exception('Login required to view favourites.');
  }
  final runtime = ref.watch(runtimeProvider);
  final transport = runtime.transport;
  if (transport == null) {
    throw Exception('Pass DAKIT_CLIENT_ID at build time.');
  }
  final page = await OfficialGalleryRepository(transport)
      .favourites(account.username, const PageRequest(limit: 24));
  return page.items;
});
