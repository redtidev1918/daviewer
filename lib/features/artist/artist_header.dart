import 'package:cached_network_image/cached_network_image.dart';
import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/sharing/app_share.dart';

/// The artist's avatar, name, real name, stats, tagline, and bio.
final class ArtistHeader extends ConsumerWidget {
  const ArtistHeader({required this.profile, super.key});

  final UserProfileDetails profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = strings(ref.watch(appLanguageProvider));
    final avatar = profile.user.avatarUri;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.placeholderColor,
                foregroundImage: avatar == null
                    ? null
                    : CachedNetworkImageProvider(avatar.toString()),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.user.displayName ?? profile.user.username,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (profile.realName case final realName?) Text(realName),
                    Text(
                      s.artistStats(
                        profile.stats.deviations,
                        profile.stats.favourites,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: s.share,
                onPressed: () => shareDeviantArtLink(
                  context,
                  uri: artistShareUri(profile.user.username),
                  title: profile.user.username,
                  strings: s,
                ),
                icon: const Icon(Icons.share_outlined),
              ),
            ],
          ),
          if (profile.tagline case final tagline?) ...[
            const SizedBox(height: 8),
            Text(
              tagline,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (profile.bio case final bio?) ...[
            const SizedBox(height: 4),
            Text(
              bio,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
