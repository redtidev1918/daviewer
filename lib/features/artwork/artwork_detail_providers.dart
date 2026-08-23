import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_state.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/data/data_access.dart';
import '../../core/data/deviation_init.dart';
import '../../core/data/html_text.dart';
import '../../core/data/web_session.dart';
import '../../core/data/web_more_like_this.dart';
import '../../core/runtime/runtime_provider.dart';
import 'artwork_store.dart';
import 'more_like_this_failure.dart';

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
      final tags = await resolveOfficialArtworkTags(
        artwork,
        fetchDetail: () {
          final runtime = ref.read(runtimeProvider);
          return dataAccessFor(runtime).artworkById(artworkId);
        },
      );
      if (tags.isNotEmpty && artwork.tags.isEmpty) {
        // Official feeds such as `/watch/deviations` return a compact artwork
        // without tags. Enrich the existing cached item instead of replacing
        // its feed-specific fields with another endpoint's representation.
        ref.read(artworkStoreProvider.notifier).putAll(<Artwork>[
          artwork.copyWith(tags: tags),
        ]);
      }
      return tags;
    });

/// Official list endpoints often omit tags even though `deviation/{id}` has
/// them. Treat an empty feed tag list as incomplete data and hydrate only then,
/// avoiding an extra request for already-complete search/gallery items.
Future<List<String>> resolveOfficialArtworkTags(
  Artwork artwork, {
  required Future<Artwork> Function() fetchDetail,
}) async {
  if (artwork.tags.isNotEmpty) return artwork.tags;
  try {
    final detailed = await fetchDetail();
    return detailed.tags;
  } on Object catch (error) {
    debugPrint('[tags] detail hydration failed for ${artwork.id}: $error');
    return const <String>[];
  }
}

/// The full rich-text HTML body of a journal deviation, fetched from the web
/// `dadeviation/init` endpoint (`type=journal`) using the embedded web session.
/// The official API only exposes a truncated excerpt for journals; the complete
/// tiptap document (inline formatting + embedded images) lives here.
final journalHtmlProvider = FutureProvider.autoDispose.family<String?, String>((
  ref,
  artworkId,
) async {
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

/// The authoritative result of probing DeviantArt's original-download
/// endpoint. [lookupError] is reserved for transient failures (network/server/
/// session resolution); expected permission denials are represented by the
/// typed [MediaAsset.availability] and [MediaAsset.availabilityReason].
final class OriginalFileResolution {
  const OriginalFileResolution({required this.asset, this.lookupError});

  final MediaAsset asset;
  final Object? lookupError;
}

final originalFileProvider = FutureProvider.autoDispose
    .family<OriginalFileResolution, String>((ref, artworkId) async {
      final cached = ref.read(artworkStoreProvider)[artworkId];
      // Journals/literature have no downloadable original — don't hit the
      // download endpoint (it 400s for journals). Text-only posts short-circuit
      // here too.
      final isJournal =
          cached != null && cached.pageUri.path.contains('/journal/');
      if (cached != null && (cached.media.isEmpty || isJournal)) {
        return OriginalFileResolution(
          asset: MediaAsset(
            id: '$artworkId:original',
            kind: MediaKind.unknown,
            role: MediaRole.original,
            availability: MediaAvailability.missing,
          ),
        );
      }
      final runtime = ref.watch(runtimeProvider);
      try {
        // Web recommendation items use numeric ids, while the official
        // download endpoint only accepts the OAuth UUID. Always probe the
        // endpoint instead of trusting a cached media URL: entitlement and
        // free-download limits are user-specific and can change at any time.
        final uuid = await ref.watch(artworkUuidProvider(artworkId).future);
        final asset = await dataAccessFor(runtime).originalFile(uuid);
        return OriginalFileResolution(asset: asset);
      } on Object catch (error) {
        // Never let a download-availability lookup take down the whole detail
        // page. Expected 4xx denials are already converted into typed assets by
        // DAKit; only transient failures reach here and remain distinguishable
        // so the UI can say that availability could not be verified and offer
        // a retry instead of falsely claiming the artwork is not downloadable.
        debugPrint('[orig] download lookup failed: $error');
        return OriginalFileResolution(
          asset: MediaAsset(
            id: '$artworkId:original',
            kind: MediaKind.unknown,
            role: MediaRole.original,
            availability: MediaAvailability.unavailable,
          ),
          lookupError: error,
        );
      }
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

/// The full author description as an HTML fragment (rich text, preserving
/// links and inline formatting). Mirrors [artworkDescriptionProvider] but keeps
/// the renderable markup instead of collapsing it to plain text.
final artworkDescriptionHtmlProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, artworkId) async {
      if (isNumericDeviationId(artworkId)) {
        try {
          final init = await ref.watch(deviationInitProvider(artworkId).future);
          final html = init?.descriptionHtml;
          if (html != null && html.trim().isNotEmpty) return html;
        } on Object {
          // Fall through to null; plain text remains available.
        }
        return null;
      }
      final runtime = ref.watch(runtimeProvider);
      try {
        final content = await OfficialArtworkContentRepository(
          runtime.transport!,
        ).get(artworkId);
        final html = content.html;
        if (html != null && html.trim().isNotEmpty) return html;
        final markup = content.originalMarkup;
        if (markup != null && markup.trim().isNotEmpty) {
          final converted = tiptapToHtml(markup);
          return converted.isNotEmpty ? converted : markup;
        }
      } on Object {
        // Fall through to null.
      }
      return null;
    });

/// "More Like This" — use the current website's organic related blocks first,
/// because they can diverge from the legacy OAuth preview endpoint. The
/// official endpoint remains a fallback when the artwork page is unavailable.
final moreLikeThisProvider = FutureProvider.autoDispose
    .family<MoreLikeThisResult, String>((ref, artworkId) async {
      final runtime = ref.watch(runtimeProvider);
      final artwork = await ref.watch(artworkDetailProvider(artworkId).future);
      final numericId = isNumericDeviationId(artworkId)
          ? artworkId
          : RegExp(r'-(\d+)/?$').firstMatch(artwork.pageUri.path)?.group(1);
      Object? websiteError;
      if (numericId != null) {
        try {
          final webSession = ref.watch(webSessionProvider);
          final cookieHeader = await webSession.cookieHeader();
          final artworks = await WebMoreLikeThisFetcher(runtime.dio!).fetch(
            pageUri: artwork.pageUri,
            deviationId: numericId,
            cookieHeader: cookieHeader,
          );
          if (artworks.isNotEmpty) {
            ref.read(artworkStoreProvider.notifier).putAll(artworks);
            debugPrint(
              '[moreLikeThis] website source returned ${artworks.length} '
              'items for $numericId',
            );
            return MoreLikeThisResult(artworks: artworks);
          }
          debugPrint('[moreLikeThis] website source empty for $numericId');
        } on Object catch (error) {
          websiteError = error;
          debugPrint(
            '[moreLikeThis] website source failed for $numericId: $error',
          );
        }
      }

      try {
        final uuid = await ref.watch(artworkUuidProvider(artworkId).future);
        final result = await OfficialDiscoveryRepository(runtime.transport!)
            .moreLikeThis(uuid);
        ref.read(artworkStoreProvider.notifier).putAll(result.artworks);
        debugPrint(
          '[moreLikeThis] OAuth source returned ${result.artworks.length} '
          'items for $uuid',
        );
        return result;
      } on Object catch (officialError) {
        throw MoreLikeThisFailure(
          websiteError: websiteError,
          officialError: officialError,
        );
      }
    });
