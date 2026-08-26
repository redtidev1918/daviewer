import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/runtime/runtime_provider.dart';
import '../artwork/artwork_store.dart';
import 'notification_read_store.dart';

/// The user's DeviantArt message-center feed (who favourited, watched or
/// commented on their work). Requires an OAuth session.
final notificationsProvider = FutureProvider.autoDispose<List<ProviderMessage>>(
  (ref) async {
    ref.watch(
      authControllerProvider.select((auth) => (auth.status, auth.account?.id)),
    );
    final runtime = ref.watch(runtimeProvider);
    final page = await OfficialMessageRepository(runtime.transport!).feed();

    // Cache any attached artwork so tapping through to the detail screen is
    // instant and consistent with the rest of the app.
    final artworks = page.items
        .map((message) => message.artwork)
        .whereType<Artwork>();
    ref.read(artworkStoreProvider.notifier).putAll(artworks);

    return page.items;
  },
);

/// How many notifications are currently unread (server `isNew` flag minus
/// locally read ids). Returns `0` when signed out or the feed fails, so the
/// Home bell simply shows no dot. Kept separate from [notificationsProvider]
/// so the app bar badge does not own the full feed state.
final notificationsUnreadCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  ref.watch(authControllerProvider.select((auth) => auth.status));
  final List<ProviderMessage> messages;
  try {
    messages = await ref.watch(notificationsProvider.future);
  } on Object {
    return 0;
  }
  if (messages.isEmpty) return 0;
  final read = await NotificationReadStore.load();
  return messages
      .where((message) => message.isNew && !read.contains(message.id))
      .length;
});
