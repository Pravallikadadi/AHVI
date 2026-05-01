import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_theme.dart';
import 'theme_storage.dart';

class ThemeController extends ChangeNotifier {
  bool isDarkMode = false;
  ProfileTheme currentTheme = ProfileTheme.coolBlue;

  // ── NEW: ThemeMode (system / light / dark) ──
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  Future<void> loadTheme() async {
    currentTheme = await ThemeStorage.loadTheme();
    // APK installs can retain old SharedPreferences from previous builds.
    // Start in light mode so Android matches the web build unless the user
    // explicitly changes theme after launch.
    final prefs = await SharedPreferences.getInstance();
    final savedIndex = prefs.getInt('themeMode');
    if (savedIndex != null && ThemeMode.values[savedIndex] == ThemeMode.dark) {
      _themeMode = ThemeMode.dark;
      isDarkMode = true;
    } else {
      _themeMode = ThemeMode.light;
      isDarkMode = false;
    }

    notifyListeners();
  }

  // ── NEW: set system / light / dark and persist it ──
  Future<void> setThemeMode(ThemeMode mode) async {
    assert(mode != ThemeMode.system, 'System mode is not supported');
    if (mode == ThemeMode.system) return;
    _themeMode = mode;
    if (mode == ThemeMode.dark) {
      isDarkMode = true;
      await ThemeStorage.saveMode(true);
    } else if (mode == ThemeMode.light) {
      isDarkMode = false;
      await ThemeStorage.saveMode(false);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  // ── KEPT: still works for any existing toggle switches ──
  Future<void> toggleBrightness() async {
    isDarkMode = !isDarkMode;
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    await ThemeStorage.saveMode(isDarkMode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', _themeMode.index);
    notifyListeners();
  }

  Future<void> setTheme(ProfileTheme theme) async {
    if (currentTheme == theme) return;
    currentTheme = theme;
    await ThemeStorage.saveTheme(theme);
    notifyListeners();
  }
}