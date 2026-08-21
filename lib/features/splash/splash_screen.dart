import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/web_session_controller.dart';
import '../../core/auth/web_session_refresher.dart';

final class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

final class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      unawaited(ref.read(authControllerProvider.notifier).initialize());
      final web = ref.read(webSessionControllerProvider.notifier);
      await web.initialize();
      // Re-establish the embedded web session silently when a prior session is
      // persisted (the CSRF token rotates, so refresh it in a hidden WebView).
      if (ref.read(webSessionControllerProvider).signedIn) {
        unawaited(ref.read(webSessionRefresherProvider).refresh());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
