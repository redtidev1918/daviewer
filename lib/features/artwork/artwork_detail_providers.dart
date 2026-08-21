import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
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
      final csrf = ref.watch(
        webSessionControllerProvider.select((web) => web.csrf),
      );
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
final artworkUuidProvider = FutureProvider.autoDispose.family<String, String>((
  ref,
  artworkId,
) async {
  if (!isNumericDeviationId(artworkId)) return artworkId;
  final init = await ref.watch(deviationInitProvider(artworkId).future);
  return init!.uuid;
});

/// Whether the signed-in user has favourited this artwork, read from the
/// mapped [Artwork.isFavourited] (no extra provider call needed).
final favouriteStatusProvider = FutureProvider.autoDispose.family<bool, String>(
  (ref, artworkId) async {
    final artwork = await ref.watch(artworkDetailProvider(artworkId).future);
    return artwork.isFavourited;
  },
);

/// Display-size assets for each additional page of a multi-image deviation
/// (web-feed items only; the official API no longer exposes these pages).
final additionalMediaProvider = FutureProvider.autoDispose
    .family<List<MediaAsset>, String>((ref, artworkId) async {
      if (!isNumericDeviationId(artworkId)) return const <MediaAsset>[];
      try {
        final init = await ref.watch(deviationInitProvider(artworkId).future);
        return init?.additionalMedia ?? const <MediaAsset>[];
      } on Object {
        return const <MediaAsset>[];
      }
    });

/// Searchable tag names for an artwork. Web-feed items read tags from the
/// `dadeviation/init` endpoint; OAuth items from the mapped [Artwork.tags].
final artworkTagsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, artworkId) async {
      if (isNumericDeviationId(artworkId)) {
        try {
          final init = await ref.watch(deviationInitProvider(artworkId).future);
          return init?.tags ?? const <String>[];
        } on Object {
          return const <String>[];
        }
      }
      final artwork = await ref.watch(artworkDetailProvider(artworkId).future);
      return artwork.tags;
    });

/// The full rich-text HTML body of a journal deviation, fetched from the web
/// `dadeviation/init` endpoint (`type=journal`) using the embedded web session.
/// The official API only exposes a truncated excerpt for journals; the complete
/// tiptap document (inline formatting + embedded images) lives here.
final journalHtmlProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, artworkId) async {
      final cached = ref.read(artworkStoreProvider)[artworkId];
      if (cached == null || !cached.pageUri.path.contains('/journal/')) {
        return null;
      }
      final match = RegExp(r'-(\d+)/?$').firstMatch(cached.pageUri.path);
      final numericId = match?.group(1);
      if (numericId == null) return null;
      final csrf = ref.watch(
        webSessionControllerProvider.select((web) => web.csrf),
      );
      if (csrf.isEmpty) return null;
      final webSession = ref.watch(webSessionProvider);
      final cookieHeader = await webSession.cookieHeader();
      final runtime = ref.watch(runtimeProvider);
      return JournalContentFetcher(runtime.dio!).fetchHtml(
        deviationId: numericId,
        username: cached.author.username,
        cookieHeader: cookieHeader,
        csrfToken: csrf,
      );
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
      // Journals/literature have no downloadable original — don't hit the
      // download endpoint (it 400s for journals). Text-only posts short-circuit
      // here too.
      final isJournal =
          cached != null && cached.pageUri.path.contains('/journal/');
      if (cached != null && (cached.media.isEmpty || isJournal)) {
        return MediaAsset(
          id: '$artworkId:original',
          kind: MediaKind.unknown,
          role: MediaRole.original,
          availability: MediaAvailability.missing,
        );
      }
      final runtime = ref.watch(runtimeProvider);
      return dataAccessFor(runtime).originalFile(artworkId);
    });

/// The full author description as plain text. For web-feed items it comes from
/// `dadeviation/init`; for OAuth items from `deviation/content`. Falls back to
/// the artwork's short excerpt when the full description is empty.
final artworkDescriptionProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, artworkId) async {
      final cached = ref.read(artworkStoreProvider)[artworkId];
      if (isNumericDeviationId(artworkId)) {
        try {
          final init = await ref.watch(deviationInitProvider(artworkId).future);
          final text = init?.description;
          if (text != null && text.trim().isNotEmpty) return text;
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
        if (html != null && html.trim().isNotEmpty) {
          return htmlToPlainText(html);
        }
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
