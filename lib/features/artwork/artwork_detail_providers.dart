import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/session_state.dart';
import '../../core/data/data_access.dart';
import '../../core/data/deviation_init.dart';
import '../../core/data/web_session.dart';
import '../../core/runtime/runtime_provider.dart';
import 'artwork_store.dart';

/// True for the numeric ids used by the web `rfy` feed (the OAuth API only
/// accepts UUIDs, e.g. `97B067C2-…`).
bool isNumericDeviationId(String id) => RegExp(r'^\d+$').hasMatch(id);

/// Resolves a numeric web-feed id to the OAuth UUID plus the full description,
/// via the private web `dadeviation/init` endpoint (web session required).
/// Returns `null` for ids that are already OAuth UUIDs.
final deviationInitProvider = FutureProvider.autoDispose
    .family<DeviationInit?, String>((ref, artworkId) async {
      if (!isNumericDeviationId(artworkId)) return null;
      final auth = ref.watch(authControllerProvider);
      final csrf = auth.webCsrf;
      if (csrf.isEmpty) throw const WebLoginRequired();
      final webSession = ref.watch(webSessionProvider);
      final cookieHeader = await webSession.cookieHeader();
      final cached = ref.read(artworkStoreProvider)[artworkId];
      final username = cached?.author.username ?? '';
      final runtime = ref.watch(runtimeProvider);
      return DeviationInitFetcher(runtime.dio!).fetch(
        deviationId: artworkId,
        username: username,
        cookieHeader: cookieHeader,
        csrfToken: csrf,
      );
    });

/// The OAuth UUID for an artwork id (numeric web ids are resolved through
/// [deviationInitProvider]).
final artworkUuidProvider = FutureProvider.autoDispose
    .family<String, String>((ref, artworkId) async {
      if (!isNumericDeviationId(artworkId)) return artworkId;
      final init = await ref.watch(deviationInitProvider(artworkId).future);
      return init!.uuid;
    });

/// Resolves an artwork by id, preferring the in-memory [artworkStoreProvider]
/// cache so web-feed items (which use a numeric id the OAuth API cannot
/// resolve) render without a failing `deviation/{id}` round-trip.
final artworkDetailProvider = FutureProvider.autoDispose
    .family<Artwork, String>((ref, artworkId) async {
      final cached = ref.read(artworkStoreProvider)[artworkId];
      if (cached != null) return cached;
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).artworkById(artworkId);
    });

final originalFileProvider = FutureProvider.autoDispose
    .family<MediaAsset, String>((ref, artworkId) async {
      final cached = ref.read(artworkStoreProvider)[artworkId];
      final cachedOriginal = cached?.media
          .where((m) => m.role == MediaRole.original)
          .firstOrNull;
      if (cachedOriginal != null) return cachedOriginal;
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).originalFile(artworkId);
    });

/// The full author description as rich-text HTML. For web-feed items it comes
/// from `dadeviation/init`; for OAuth items from `deviation/content`.
final artworkDescriptionProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, artworkId) async {
      if (isNumericDeviationId(artworkId)) {
        final init = await ref.watch(deviationInitProvider(artworkId).future);
        return init?.descriptionHtml;
      }
      final runtime = ref.watch(runtimeProvider);
      try {
        final content = await OfficialArtworkContentRepository(
          runtime.transport!,
        ).get(artworkId);
        return content.html;
      } on Object catch (error) {
        debugPrint('[desc] content fetch failed: $error');
        return null;
      }
    });
