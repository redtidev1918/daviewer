import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/data_access.dart';
import '../../core/runtime/runtime_provider.dart';

final artworkDetailProvider = FutureProvider.autoDispose
    .family<Artwork, String>((ref, artworkId) async {
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).artworkById(artworkId);
    });

final originalFileProvider = FutureProvider.autoDispose
    .family<MediaAsset, String>((ref, artworkId) async {
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).originalFile(artworkId);
    });

/// Description fetched from the public web page (the official API no longer
/// returns author descriptions).
final artworkDescriptionProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, artworkId) async {
      final runtime = ref.watch(runtimeProvider);
      final artwork = await dataAccessFor(runtime).artworkById(artworkId);
      final description = await dataAccessFor(runtime).artworkDescription(
        artwork,
      );
      debugPrint('[desc] artwork=$artworkId len=${description?.length ?? 0}');
      return description;
    });
