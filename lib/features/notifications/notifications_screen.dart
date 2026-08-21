import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_core/dakit_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import 'notifications_providers.dart';

/// The user's DeviantArt notifications (message center). Each entry shows
/// *which user* triggered the notification (the originator), what they did,
/// and the affected artwork.
final class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final isZh = ref.watch(appLanguageProvider) == AppLanguage.zh;
    final messages = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(s.notifications)),
      body: messages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsProvider.future),
          child: _ScrollableFill(
            child: AppErrorState(
              message: _friendlyError(error, isZh),
              onRetry: () => ref.invalidate(notificationsProvider),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(notificationsProvider.future),
              child: _ScrollableFill(
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
                  _MessageTile(message: items[index], isZh: isZh),
            ),
          );
        },
      ),
    );
  }
}

final class _MessageTile extends StatelessWidget {
  const _MessageTile({required this.message, required this.isZh});

  final ProviderMessage message;
  final bool isZh;

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
        username.isEmpty ? (isZh ? '未知用户' : 'Unknown user') : '@$username',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _typeLabel(message.type, isZh) + (artwork == null ? '' : ' · ${artwork.title}'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _relativeTime(message.postedAt, isZh),
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
                placeholder: (context, url) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: ColoredBox(color: Color(0xffe9ecef)),
                ),
                errorWidget: (context, url, error) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: ColoredBox(
                    color: Color(0xffe9ecef),
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
      child: Text((username?.isNotEmpty ?? false) ? username![0].toUpperCase() : '?'),
    );
    final uri = url;
    if (uri == null || uri.isEmpty) return fallback;
    return CachedNetworkImage(
      imageUrl: uri,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        backgroundImage: imageProvider,
      ),
      placeholder: (context, url) => fallback,
      errorWidget: (context, url, error) => fallback,
    );
  }
}

String _typeLabel(String type, bool isZh) {
  final label = switch (type) {
    'watched' || 'watch' => isZh ? '关注了你' : 'watched you',
    'deviation' || 'new_deviation' || 'posted' =>
      isZh ? '更新了作品' : 'posted new work',
    'deviation_faved' ||
    'faved' ||
    'favourited' =>
      isZh ? '收藏了你的作品' : 'favourited your work',
    'deviation_comment' ||
    'comment_deviation' ||
    'comment' =>
      isZh ? '评论了你的作品' : 'commented on your work',
    'mention' || 'mention_deviation' => isZh ? '提到了你' : 'mentioned you',
    'collection' || 'added_to_collection' =>
      isZh ? '把你的作品加入收藏集' : 'added your work to a collection',
    'journal' || 'journal_faved' =>
      isZh ? '发布了日志' : 'posted a journal',
    'gift' => isZh ? '送了你礼物' : 'sent you a gift',
    'note' => isZh ? '给你发了私信' : 'sent you a note',
    'llama' => isZh ? '送你一个 Llama' : 'gave you a Llama',
    'status' || 'status_update' => isZh ? '更新了状态' : 'updated their status',
    _ => (isZh ? '更新了动态' : 'posted an update'),
  };
  return label;
}

String _friendlyError(Object error, bool isZh) {
  if (error is DAKitException) {
    switch (error.kind) {
      case DAKitFailureKind.authentication:
      case DAKitFailureKind.authorization:
        return isZh
            ? '登录授权已过期或缺少「通知」权限，请退出登录后重新登录一次。'
            : 'Your login is missing the notifications permission. Please log out and log back in once.';
      default:
        break;
    }
  }
  return '$error';
}

String _relativeTime(DateTime? time, bool isZh) {
  if (time == null) return '';
  final diff = DateTime.now().difference(time.toLocal());
  if (diff.inMinutes < 1) return isZh ? '刚刚' : 'now';
  if (diff.inHours < 1) return isZh ? '${diff.inMinutes} 分钟前' : '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return isZh ? '${diff.inHours} 小时前' : '${diff.inHours}h ago';
  if (diff.inDays < 30) return isZh ? '${diff.inDays} 天前' : '${diff.inDays}d ago';
  final local = time.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day';
}

final class _ScrollableFill extends StatelessWidget {
  const _ScrollableFill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: child,
        ),
      ),
    );
  }
}
