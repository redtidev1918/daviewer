import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/skeleton.dart';
import 'search_providers.dart';

/// The user-search results list.
final class UserResults extends ConsumerWidget {
  const UserResults({required this.query, super.key});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(userSearchProvider(query));
    final s = strings(ref.watch(appLanguageProvider));
    return users.when(
      loading: () => const SkeletonList(),
      error: (error, stackTrace) =>
          AppErrorState(message: friendlyErrorMessage(error)),
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            message: s.noUsersFound,
            icon: Icons.person_search_outlined,
          );
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = items[index];
            return ListTile(
              leading: _UserAvatar(user: user),
              title: Text(user.username),
              subtitle: user.displayName == null
                  ? null
                  : Text(user.displayName!),
              onTap: () => context.push('/artist/${user.username}'),
            );
          },
        );
      },
    );
  }
}

final class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final uri = user.avatarUri?.toString();
    final fallback = CircleAvatar(
      child: Text(user.username.isEmpty ? '?' : user.username[0].toUpperCase()),
    );
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
