import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gerer le theme de l'app (clair/sombre)
class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  static ThemeService get instance => _instance;
  
  ThemeService._internal();

  static const String _themeKey = 'theme_mode';
  
  // Par defaut, suivre le systeme
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  /// Initialise le service en chargeant le theme sauvegarde
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final themeValue = prefs.getString(_themeKey);
    if (themeValue != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == themeValue,
        orElse: () => ThemeMode.system,
      );
    }
    notifyListeners();
  }

  /// Change le theme et le sauvegarde
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }

  /// Toggle entre light et dark (ignore system)
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }

  /// Active le mode sombre
  Future<void> setDarkMode(bool isDark) async {
    await setThemeMode(isDark ? ThemeMode.dark : ThemeMode.light);
  }
}
