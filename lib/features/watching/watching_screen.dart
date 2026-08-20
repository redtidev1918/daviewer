import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/runtime/runtime_provider.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';

/// Lists the users the current account is watching (following).
final class WatchingScreen extends ConsumerStatefulWidget {
  const WatchingScreen({super.key});

  @override
  ConsumerState<WatchingScreen> createState() => _WatchingScreenState();
}

final class _WatchingScreenState extends ConsumerState<WatchingScreen> {
  final List<UserRelationship> _items = <UserRelationship>[];
  bool _loading = true;
  Object? _error;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final runtime = ref.read(runtimeProvider);
      final account = ref.read(authControllerProvider).account;
      if (account == null) {
        throw StateError('not signed in');
      }
      final page = await OfficialUserRepository(
        runtime.transport!,
      ).friends(account.username, const PageRequest(limit: 24));
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _nextCursor == null) return;
    setState(() => _loading = true);
    try {
      final runtime = ref.read(runtimeProvider);
      final account = ref.read(authControllerProvider).account;
      if (account == null) throw StateError('not signed in');
      final page = await OfficialUserRepository(
        runtime.transport!,
      ).friends(account.username, PageRequest(cursor: _nextCursor, limit: 24));
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextCursor = page.nextCursor;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(ref.watch(appLanguageProvider));
    final isZh = ref.watch(appLanguageProvider) == AppLanguage.zh;
    return Scaffold(
      appBar: AppBar(title: Text(isZh ? '关注用户' : 'Watching')),
      body: _buildBody(context, s, isZh),
    );
  }

  Widget _buildBody(BuildContext context, AppStrings s, bool isZh) {
    if (_error != null && _items.isEmpty) {
      final message = '$_error';
      final isForbidden = message.contains('403') ||
          message.contains('authorization') ||
          message.contains('Forbidden');
      return AppErrorState(
        message: isForbidden
            ? (isZh
                ? '获取关注列表失败：权限不足。\n'
                    '请退出登录后重新登录，以获取最新权限。'
                : 'Permission denied. Please sign out and sign in again.')
            : message,
        onRetry: _load,
      );
    }
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_items.isEmpty) {
      return AppEmptyState(message: isZh ? '尚未关注任何用户' : 'No watched users');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 400) {
            _loadMore();
          }
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(8),
          itemCount: _items.length + (_loading ? 1 : 0),
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            if (index >= _items.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final relation = _items[index];
            final user = relation.user;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xffe9ecef),
                foregroundImage: user.avatarUri == null
                    ? null
                    : CachedNetworkImageProvider(user.avatarUri.toString()),
                child: user.avatarUri == null
                    ? Text(user.username.isNotEmpty
                        ? user.username[0].toUpperCase()
                        : '?')
                    : null,
              ),
              title: Text(user.displayName ?? user.username),
              subtitle: Text(user.username),
              onTap: () => context.push('/artist/${user.username}'),
            );
          },
        ),
      ),
    );
  }
}
