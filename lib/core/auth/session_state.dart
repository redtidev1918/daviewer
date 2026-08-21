import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/web_session.dart';

/// Reads the deviantart.com web session cookies.
final webSessionProvider = Provider<WebSession>((ref) => const WebSession());
