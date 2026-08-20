import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';

final homeFeedProvider = FutureProvider.autoDispose<List<Artwork>>((ref) async {
  final runtime = ref.watch(runtimeProvider);
  final transport = runtime.transport;
  if (transport == null) {
    throw Exception('Pass DAKIT_CLIENT_ID at build time.');
  }
  final page = await OfficialArtworkRepository(transport)
      .browse(const PageRequest(limit: 24));
  return page.items;
});
