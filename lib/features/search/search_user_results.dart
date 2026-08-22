import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/diagnostics/error_text.dart';
import '../../core/l10n/app_strings.dart';
import '../../shared/widgets/app_error_state.dart';
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          AppErrorState(message: friendlyErrorMessage(error)),
      data: (items) {
        if (items.isEmpty) {
          return Center(child: Text(s.noUsersFound));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = items[index];
            return ListTile(
              leading: user.avatarUri == null
                  ? const CircleAvatar(child: Icon(Icons.person))
                  : CircleAvatar(
                      foregroundImage: NetworkImage(user.avatarUri.toString()),
                    ),
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
