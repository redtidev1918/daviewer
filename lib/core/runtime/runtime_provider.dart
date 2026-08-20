import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_runtime.dart';

final runtimeProvider = Provider<AppRuntime>(
  (ref) =>
      throw UnimplementedError('runtimeProvider must be overridden in main.'),
);
