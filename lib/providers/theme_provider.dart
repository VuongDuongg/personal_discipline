import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/shared_prefs_service.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final isDark = SharedPreferencesService.instance.isDarkMode;
  return ThemeModeNotifier(isDark ? ThemeMode.dark : ThemeMode.light);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initialMode);

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      state = ThemeMode.light;
      SharedPreferencesService.instance.setDarkMode(false);
    } else {
      state = ThemeMode.dark;
      SharedPreferencesService.instance.setDarkMode(true);
    }
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    SharedPreferencesService.instance.setDarkMode(mode == ThemeMode.dark);
  }
}

