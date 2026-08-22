import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme.dart';
import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/scrollable_fill.dart';
import 'notifications_providers.dart';

/// The user's DeviantArt notifications (message center). Each entry shows
/// *which user* triggered the notification (the originator), what they did,
/// and the affected artwork.
final class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final messages = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.notifications)),
      body: messages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: ScrollableFill(
            child: AppErrorState(
              message: _friendlyError(error, s),
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(notificationsProvider.future),
              child: ScrollableFill(
                child: AppEmptyState(
                  message: s.noNotifications,
                  icon: Icons.notifications_none,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(notificationsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _MessageTile(message: items[index], s: s),
            ),
          );
        },
      ),
    );
  }
}

final class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.s});

  final ProviderMessage message;
  final AppStrings s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final originator = message.originator ?? message.profile;
    final artwork = message.artwork;
    final username = originator?.username ?? '';
    final thumbnail = artwork?.media.firstOrNull;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(
        url: originator?.avatarUri?.toString(),
        username: username.isEmpty ? artwork?.author.username : username,
      ),
      title: Text(
        username.isEmpty ? s.unknownUser : '@$username',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        s.notificationTypeLabel(message.type) +
            (artwork == null ? '' : ' · ${artwork.title}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            s.relativeTime(message.postedAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (thumbnail?.uri case final uri?) ...[
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CachedNetworkImage(
                imageUrl: uri.toString(),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                memCacheWidth: 120,
                placeholder: (context, url) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: ColoredBox(color: AppTheme.placeholderColor),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: ColoredBox(
                    color: AppTheme.placeholderColor,
                    child: Icon(Icons.image, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        if (artwork != null) {
          context.push('/artwork/${artwork.id}');
        } else if (originator != null && originator.username.isNotEmpty) {
          context.push('/artist/${originator.username}');
        }
      },
    );
  }
}

final class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.username});

  final String? url;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      child: Text(
        (username?.isNotEmpty ?? false) ? username![0].toUpperCase() : '?',
      ),
    );
    final uri = url;
    if (uri == null || uri.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: uri,
      memCacheWidth: 120,
      imageBuilder: (context, imageProvider) =>
          CircleAvatar(backgroundImage: imageProvider),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

String _friendlyError(Object error, AppStrings s) {
  if (error is DAKitException) {
    switch (error.kind) {
      case DAKitFailureKind.authentication:
      case DAKitFailureKind.authorization:
        return s.notifPermissionError;
      default:
        break;
    }
  }
  return friendlyErrorMessage(error);
}
