import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/web_session_controller.dart';
import '../../core/auth/web_session_refresher.dart';
import '../../core/diagnostics/app_logger.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/artwork_card.dart';
import 'artwork_detail_providers.dart';
import 'artwork_navigation.dart';
import 'more_like_this_failure.dart';

/// A masonry (waterfall) grid of "More Like This" deviations shown below an
/// artwork, matching the modern feed layout. Hides itself when empty.
///
/// This is the reference pattern for related-content sections: a self-contained
/// widget that owns its provider and handles loading/error/empty internally.
final class MoreLikeThisSection extends ConsumerStatefulWidget {
  const MoreLikeThisSection({required this.artworkId, super.key});

  final String artworkId;

  @override
  ConsumerState<MoreLikeThisSection> createState() =>
      _MoreLikeThisSectionState();
}

final class _MoreLikeThisSectionState
    extends ConsumerState<MoreLikeThisSection> {
  String? _autoRetriedFor;
  String? _loggedFailure;
  bool _recovering = false;

  @override
  void didUpdateWidget(covariant MoreLikeThisSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.artworkId == widget.artworkId) return;
    _autoRetriedFor = null;
    _loggedFailure = null;
    _recovering = false;
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final related = ref.watch(moreLikeThisProvider(widget.artworkId));

    return related.when(
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) {
        _logFailure(error);
        final kind = error is MoreLikeThisFailure
            ? error.kind
            : classifyMoreLikeThisFailure(<Object?>[error]);
        final canRecoverAutomatically =
            kind == MoreLikeThisFailureKind.network ||
            kind == MoreLikeThisFailureKind.session;
        if (canRecoverAutomatically && _autoRetriedFor != widget.artworkId) {
          _scheduleAutomaticRetry();
          return _RecoveryStatus(
            message: s.moreLikeThisRecovering,
            title: s.moreLikeThis,
          );
        }
        if (_recovering) {
          return _RecoveryStatus(
            message: s.moreLikeThisRecovering,
            title: s.moreLikeThis,
          );
        }
        final message = switch (kind) {
          MoreLikeThisFailureKind.network => s.moreLikeThisNetworkFailure,
          MoreLikeThisFailureKind.session => s.moreLikeThisSessionFailure,
          MoreLikeThisFailureKind.service => s.moreLikeThisServiceFailure,
          MoreLikeThisFailureKind.pageFormat => s.moreLikeThisFormatFailure,
          MoreLikeThisFailureKind.unknown => s.moreLikeThisUnknownFailure,
        };
        final icon = switch (kind) {
          MoreLikeThisFailureKind.network => Icons.wifi_off_outlined,
          MoreLikeThisFailureKind.session => Icons.lock_clock_outlined,
          MoreLikeThisFailureKind.service => Icons.cloud_off_outlined,
          MoreLikeThisFailureKind.pageFormat => Icons.code_off_outlined,
          MoreLikeThisFailureKind.unknown => Icons.info_outline,
        };
        return _RelatedStatus(
          title: s.moreLikeThis,
          icon: icon,
          message: message,
          action: TextButton.icon(
            onPressed: kind == MoreLikeThisFailureKind.session
                ? () async {
                    await context.push<void>('/web-login');
                    if (mounted) await _manualRetry();
                  }
                : _manualRetry,
            icon: Icon(
              kind == MoreLikeThisFailureKind.session
                  ? Icons.login
                  : Icons.refresh,
            ),
            label: Text(
              kind == MoreLikeThisFailureKind.session
                  ? s.login
                  : s.reloadSuggestions,
            ),
          ),
        );
      },
      data: (result) {
        final items = result.artworks;
        if (items.isEmpty) {
          AppLogger.instance.warning(
            'moreLikeThis',
            'empty related result for ${widget.artworkId}',
          );
          return _RelatedStatus(
            title: s.moreLikeThis,
            icon: Icons.auto_awesome_outlined,
            message: s.noMoreLikeThis,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              s.moreLikeThis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            MasonryGridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final artwork = items[index];
                return AspectRatio(
                  aspectRatio: artworkAspectRatio(artwork),
                  child: ArtworkCard(
                    artwork: artwork,
                    onTap: () => openArtworkFromList(
                      context,
                      ref,
                      artworks: items,
                      artwork: artwork,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _logFailure(Object error) {
    final signature = '$error';
    if (_loggedFailure == signature) return;
    _loggedFailure = signature;
    debugPrint('[moreLikeThis] ${widget.artworkId} failed: $error');
    AppLogger.instance.error(
      'moreLikeThis',
      'failed for ${widget.artworkId}',
      error,
    );
  }

  void _scheduleAutomaticRetry() {
    _autoRetriedFor = widget.artworkId;
    _recovering = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _retry();
      if (mounted) setState(() => _recovering = false);
    });
  }

  Future<void> _manualRetry() async {
    if (_recovering) return;
    setState(() => _recovering = true);
    await _retry();
    if (mounted) setState(() => _recovering = false);
  }

  Future<void> _retry() async {
    // Numeric web-feed ids need a current web CSRF token before they can be
    // resolved to the UUID accepted by the official endpoint. Await the real
    // headless refresh completion, then invalidate the whole resolution chain.
    try {
      if (isNumericDeviationId(widget.artworkId) &&
          ref.read(webSessionControllerProvider).signedIn) {
        await ref.read(webSessionRefresherProvider).refresh();
      }
    } on Object catch (error, stackTrace) {
      AppLogger.instance.warning(
        'moreLikeThis',
        'session refresh failed for ${widget.artworkId}',
        error,
        stackTrace,
      );
    }
    if (!mounted) return;
    ref.invalidate(deviationInitProvider(widget.artworkId));
    ref.invalidate(artworkUuidProvider(widget.artworkId));
    ref.invalidate(moreLikeThisProvider(widget.artworkId));
  }
}

final class _RecoveryStatus extends StatelessWidget {
  const _RecoveryStatus({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _RelatedStatus(
    title: title,
    icon: Icons.sync,
    message: message,
    progress: true,
  );
}

final class _RelatedStatus extends StatelessWidget {
  const _RelatedStatus({
    required this.title,
    required this.icon,
    required this.message,
    this.action,
    this.progress = false,
  });

  final String title;
  final IconData icon;
  final String message;
  final Widget? action;
  final bool progress;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Row(
        children: <Widget>[
          if (progress)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          ?action,
        ],
      ),
    ],
  );
}
