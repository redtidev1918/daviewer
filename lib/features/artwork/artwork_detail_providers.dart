import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/session_state.dart';
import '../../core/data/data_access.dart';
import '../../core/data/deviation_init.dart';
import '../../core/data/html_text.dart';
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

/// Whether the signed-in user has favourited this artwork, read from the
/// official `deviation/{uuid}` response so the heart reflects the real state.
final favouriteStatusProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, artworkId) async {
      final uuid = await ref.watch(artworkUuidProvider(artworkId).future);
      final runtime = ref.watch(runtimeProvider);
      final json = await runtime.transport!.getJson(
        'deviation/${Uri.encodeComponent(uuid)}',
        query: const <String, Object?>{'with_session': false},
      );
      return json['is_favourited'] == true;
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

/// The full author description as HTML/plain text. For web-feed items it comes
/// from `dadeviation/init`; for OAuth items from `deviation/content`. Falls
/// back to the artwork's short excerpt when the full description is empty.
final artworkDescriptionProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, artworkId) async {
      final cached = ref.read(artworkStoreProvider)[artworkId];
      if (isNumericDeviationId(artworkId)) {
        try {
          final init = await ref.watch(deviationInitProvider(artworkId).future);
          final html = init?.descriptionHtml;
          if (html != null && html.trim().isNotEmpty) return html;
        } on Object catch (error) {
          debugPrint('[desc] init fetch failed: $error');
        }
        return cached?.description;
      }
      final runtime = ref.watch(runtimeProvider);
      final artwork = await ref.watch(artworkDetailProvider(artworkId).future);
      try {
        final content = await OfficialArtworkContentRepository(
          runtime.transport!,
        ).get(artworkId);
        final html = content.html;
        debugPrint('[desc] content html len=${html?.length ?? 0}');
        if (html != null && html.trim().isNotEmpty) return html;
        // The rendered `html` is empty for some deviations; the description
        // then lives in the tiptap `original_markup` document.
        final markup = content.originalMarkup;
        if (markup != null && markup.trim().isNotEmpty) {
          final text = tiptapToPlainText(markup);
          debugPrint('[desc] tiptap len=${text.length}');
          if (text.isNotEmpty) return text;
        }
      } on Object catch (error) {
        debugPrint('[desc] content fetch failed: $error');
      }
      return artwork.description;
    });
