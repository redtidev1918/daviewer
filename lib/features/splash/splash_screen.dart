import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_state.dart';

final class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

final class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(authControllerProvider.notifier).initialize());
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, auth) {
      if (auth.status != AuthStatus.unknown && mounted) {
        context.go('/');
      }
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
