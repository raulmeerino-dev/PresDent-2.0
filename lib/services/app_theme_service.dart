import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class AppThemeService {
  AppThemeService._();

  static final AppThemeService instance = AppThemeService._();
  static const _themeModeKey = 'ui.theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> loadThemeMode() async {
    final stored = await DatabaseHelper.instance.getAppSetting(_themeModeKey);
    themeMode.value = _parseMode(stored);
  }

  Future<void> setDarkMode(bool enabled) async {
    final mode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (themeMode.value != mode) {
      themeMode.value = mode;
    }
    await DatabaseHelper.instance.setAppSetting(_themeModeKey, _serializeMode(mode));
  }

  ThemeMode _parseMode(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.light;
    }
  }

  String _serializeMode(ThemeMode mode) {
    return mode == ThemeMode.dark ? 'dark' : 'light';
  }
}
