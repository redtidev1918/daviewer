import 'package:dakit_flutter/dakit_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/runtime/runtime_provider.dart';

final downloadsProvider = FutureProvider.autoDispose<List<TransferSnapshot>>((
  ref,
) async {
  final manager = ref.watch(runtimeProvider).transfers;
  await manager.initialize();
  return manager.records();
});
