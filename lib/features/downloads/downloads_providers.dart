import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';

/// Live list of downloads. Unlike a one-shot future, this listens to the
/// transfer manager's update stream and refreshes automatically whenever a
/// download progresses, pauses, completes, or fails.
final class DownloadsController extends StateNotifier<DownloadsState> {
  DownloadsController(this._ref) : super(const DownloadsState.loading()) {
    _subscribe();
  }

  final Ref _ref;

  void _subscribe() {
    final manager = _ref.read(runtimeProvider).transfers;
    manager.updates.listen((_) {
      _reload();
    });
    _reload();
  }

  Future<void> _reload() async {
    try {
      final manager = _ref.read(runtimeProvider).transfers;
      await manager.initialize();
      final records = await manager.records();
      if (!mounted) return;
      state = DownloadsState.data(records);
    } on Object catch (error) {
      if (!mounted) return;
      state = DownloadsState.error(error);
    }
  }

  Future<void> refresh() => _reload();

  /// Removes all finished transfers (completed/failed/cancelled) from the
  /// persisted records. The downloaded files are left in place.
  Future<void> clearCompleted() async {
    final manager = _ref.read(runtimeProvider).transfers;
    final records = await manager.records();
    for (final record in records) {
      if (record.isFinal) {
        await manager.remove(record.id);
      }
    }
    await _reload();
  }
}

final class DownloadsState {
  const DownloadsState.loading()
    : items = const <TransferSnapshot>[],
      isLoading = true,
      error = null;

  const DownloadsState.data(this.items) : isLoading = false, error = null;

  const DownloadsState.error(this.error)
    : items = const <TransferSnapshot>[],
      isLoading = false;

  final List<TransferSnapshot> items;
  final bool isLoading;
  final Object? error;
}

final downloadsProvider =
    StateNotifierProvider<DownloadsController, DownloadsState>(
      (ref) => DownloadsController(ref),
    );
