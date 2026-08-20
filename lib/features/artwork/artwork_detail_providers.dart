import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';

final artworkDetailProvider = FutureProvider.autoDispose
    .family<Artwork, String>((ref, artworkId) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      return OfficialArtworkRepository(transport).getById(artworkId);
    });

final originalFileProvider = FutureProvider.autoDispose
    .family<MediaAsset, String>((ref, artworkId) async {
      final runtime = ref.watch(runtimeProvider);
      final transport = runtime.transport;
      if (transport == null) {
        throw Exception('Pass DAKIT_CLIENT_ID at build time.');
      }
      return OfficialMediaRepository(transport).originalFile(artworkId);
    });
