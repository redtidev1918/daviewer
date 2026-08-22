import 'dart:async';

import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:daviewer/features/downloads/downloads_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'progress snapshots update rows without re-reading all records',
    () async {
      final manager = FakeTransferManager(<TransferSnapshot>[
        const TransferSnapshot(
          id: 'task-1',
          state: TransferState.queued,
          progress: 0,
        ),
      ]);
      final controller = DownloadsController(manager);
      await pumpEventQueue();

      manager.emit(
        const TransferSnapshot(
          id: 'task-1',
          state: TransferState.running,
          progress: 0.5,
        ),
      );
      await pumpEventQueue();

      expect(controller.state.items.single.progress, 0.5);
      expect(manager.recordsCalls, 1);

      controller.dispose();
      await pumpEventQueue();
      expect(manager.hasUpdateListener, isFalse);
      await manager.dispose();
    },
  );

  test(
    'an event arriving during a database read cannot regress progress',
    () async {
      final gate = Completer<void>();
      final manager = FakeTransferManager(<TransferSnapshot>[
        const TransferSnapshot(
          id: 'task-1',
          state: TransferState.queued,
          progress: 0,
        ),
      ])..recordsGate = gate;
      final controller = DownloadsController(manager);
      await pumpEventQueue();

      manager.emit(
        const TransferSnapshot(
          id: 'task-1',
          state: TransferState.running,
          progress: 0.75,
        ),
      );
      gate.complete();
      await pumpEventQueue();

      expect(controller.state.items.single.progress, 0.75);
      controller.dispose();
      await manager.dispose();
    },
  );

  test(
    'partial deletion failure reloads and keeps the failed record visible',
    () async {
      final manager = FakeTransferManager(<TransferSnapshot>[
        const TransferSnapshot(
          id: 'done',
          state: TransferState.completed,
          progress: 1,
        ),
        const TransferSnapshot(
          id: 'failed-delete',
          state: TransferState.failed,
          progress: 0.4,
        ),
      ])..removeFailures.add('failed-delete');
      final controller = DownloadsController(manager);
      await pumpEventQueue();

      await expectLater(controller.deleteFinished(), throwsStateError);

      expect(controller.state.isDeleting, isFalse);
      expect(controller.state.items.map((item) => item.id), <String>[
        'failed-delete',
      ]);
      expect(manager.removeAttempts, <String>['done', 'failed-delete']);

      controller.dispose();
      await manager.dispose();
    },
  );
}

final class FakeTransferManager implements TransferManager {
  FakeTransferManager(List<TransferSnapshot> records)
    : _records = List<TransferSnapshot>.of(records);

  final StreamController<TransferSnapshot> _updates =
      StreamController<TransferSnapshot>.broadcast();
  final List<TransferSnapshot> _records;
  final List<String> removeAttempts = <String>[];
  final Set<String> removeFailures = <String>{};
  int recordsCalls = 0;
  Completer<void>? recordsGate;

  bool get hasUpdateListener => _updates.hasListener;

  void emit(TransferSnapshot snapshot) => _updates.add(snapshot);

  @override
  Stream<TransferSnapshot> get updates => _updates.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<TransferSnapshot>> records() async {
    recordsCalls++;
    await recordsGate?.future;
    return List<TransferSnapshot>.of(_records);
  }

  @override
  Future<void> remove(String id) async {
    removeAttempts.add(id);
    if (removeFailures.contains(id)) throw StateError('delete failed');
    _records.removeWhere((record) => record.id == id);
  }

  @override
  Future<TransferSnapshot> enqueue(TransferRequest request) =>
      throw UnimplementedError();

  @override
  Future<void> pause(String id) async {}

  @override
  Future<void> resume(String id) async {}

  @override
  Future<void> cancel(String id) async {}

  @override
  Future<String?> moveToSharedStorage(
    String id,
    TransferSharedStorage destination,
  ) async => null;

  @override
  Future<void> configureProxy(ProxyConfiguration? proxy) async {}

  @override
  Future<void> dispose() => _updates.close();
}
