import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/runtime_provider.dart';
import '../settings/app_preferences.dart';

/// The running app version, taken from the Flutter build name at compile time.
/// The release workflow derives it from `pubspec.yaml`; debug runs report
/// `development`.
const String appVersion = String.fromEnvironment(
  'FLUTTER_BUILD_NAME',
  defaultValue: 'development',
);

/// The public GitHub release used to detect newer builds. No authentication and
/// no user data are involved; this is the same URL a browser would fetch.
const String _latestReleaseUrl =
    'https://api.github.com/repos/redtidev1918/daviewer/releases/latest';

/// Compares two dot-separated semantic versions; positive when `a` is newer.
int compareVersions(String a, String b) {
  final av = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final bv = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final length = av.length > bv.length ? av.length : bv.length;
  for (var i = 0; i < length; i++) {
    final x = i < av.length ? av[i] : 0;
    final y = i < bv.length ? bv[i] : 0;
    if (x != y) return x - y;
  }
  return 0;
}

/// Whether a string is a plain semantic version we can compare against.
bool isSemver(String value) => RegExp(r'^\d+(\.\d+)*$').hasMatch(value);

final class UpdateCheckState {
  const UpdateCheckState({this.checking = false, this.latestVersion});

  final bool checking;
  final String? latestVersion;

  bool get hasUpdate => latestVersion != null;
}

final updateCheckControllerProvider =
    StateNotifierProvider<UpdateCheckController, UpdateCheckState>(
      (ref) => UpdateCheckController(ref),
    );

/// Checks for a newer release at most once per day, silently. The result is
/// surfaced as a dismissible banner, never a modal, and a version the user has
/// dismissed is never shown again. Every failure stays silent.
final class UpdateCheckController extends StateNotifier<UpdateCheckState> {
  UpdateCheckController(this._ref) : super(const UpdateCheckState()) {
    unawaited(check());
  }

  final Ref _ref;

  Future<void> check() async {
    if (state.checking) return;
    final lastCheck = await AppPreferences.loadLastUpdateCheck();
    final now = DateTime.now().millisecondsSinceEpoch;
    // Throttle to once per hour (generous against GitHub's 60 req/hr rate
    // limit) so a release shows up on the next launch or resume instead of
    // being suppressed for a whole day.
    if (lastCheck != null &&
        now - lastCheck < const Duration(hours: 1).inMilliseconds) {
      return;
    }
    await AppPreferences.saveLastUpdateCheck(now);
    state = const UpdateCheckState(checking: true);
    try {
      final dio = _ref.read(runtimeProvider).dio;
      if (dio == null) {
        state = const UpdateCheckState();
        return;
      }
      final response = await dio.get<Object?>(_latestReleaseUrl);
      final data = response.data;
      final latest = data is Map && data['tag_name'] is String
          ? (data['tag_name'] as String).replaceFirst(RegExp('^v'), '')
          : null;
      if (latest == null || !isSemver(latest) || !isSemver(appVersion)) {
        state = const UpdateCheckState();
        return;
      }
      if (compareVersions(latest, appVersion) <= 0) {
        state = const UpdateCheckState();
        return;
      }
      final dismissed = await AppPreferences.loadDismissedUpdateVersion();
      if (dismissed == latest) {
        state = const UpdateCheckState();
        return;
      }
      state = UpdateCheckState(latestVersion: latest);
    } on Object {
      // The update check must never surface an error to the user.
      state = const UpdateCheckState();
    }
  }

  Future<void> dismiss(String version) async {
    await AppPreferences.saveDismissedUpdateVersion(version);
    state = const UpdateCheckState();
  }
}
