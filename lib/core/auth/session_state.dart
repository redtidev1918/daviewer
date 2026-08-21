import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/web_session.dart';
import '../runtime/runtime_provider.dart';

/// Reads the DeviantArt web session (Cookie + CSRF).
final webSessionProvider = Provider<WebSession>((ref) {
  final runtime = ref.watch(runtimeProvider);
  final dio = runtime.dio;
  if (dio == null) throw StateError('runtime.dio is not configured');
  return WebSession(dio);
});
