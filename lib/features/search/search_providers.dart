import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<Artwork>, String>((ref, query) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      final page = await OfficialArtworkRepository(transport)
          .search(query, const PageRequest(limit: 24));
      return page.items;
    });
