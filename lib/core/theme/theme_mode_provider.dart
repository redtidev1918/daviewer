import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The user-selected theme mode (system / light / dark). In-memory only, like
/// the language choice; it defaults to following the system theme.
final class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system);

  void set(ThemeMode mode) => state = mode;
}

final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
