import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/accent_color_service.dart';

class AppTheme {
  // Couleur d'accent dynamique - utilise AccentColorService
  static Color get skyBlue => AccentColorService.instance.accentColor;
  static Color get skyLight => AccentColorService.instance.accentLight;
  static Color get skyDark => AccentColorService.instance.accentDark;
  static Color get skyPale => AccentColorService.instance.accentPale;

  // Fonds
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color bgDark = Color(0xFF0C1929);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF152238);
  static const Color cardDark = Color(0xFF1E3A5F);

  // Textes
  static const Color textDark = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFFF1F5F9);
  static const Color textMutedDark = Color(0xFF94A3B8);

  // Couleurs pour les notes
  static const List<Color> noteColors = [
    Color(0xFFFFFFFF), // Blanc
    Color(0xFFE0F2FE), // Sky pale
    Color(0xFFF0FDF4), // Emerald pale
    Color(0xFFFEF3C7), // Amber pale
    Color(0xFFFCE7F3), // Rose pale
    Color(0xFFF3E8FF), // Violet pale
    Color(0xFFFFEDD5), // Orange pale
    Color(0xFFE0E7FF), // Indigo pale
    Color(0xFFCCFBF1), // Teal pale
  ];

  // Themes statiques (pour compatibilite)
  static ThemeData get lightTheme => getLightTheme(skyBlue);
  static ThemeData get darkTheme => getDarkTheme(skyBlue);

  // Themes dynamiques avec couleur d'accent
  static ThemeData getLightTheme(Color accentColor) {
    final accentLight = Color.lerp(accentColor, Colors.white, 0.3)!;
    
    return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        secondary: accentLight,
        tertiary: accentColor,
      surface: surfaceLight,
        background: bgLight,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
        onSurface: textDark,
        onBackground: textDark,
    ),
      scaffoldBackgroundColor: bgLight,
      appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: accentColor,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          color: textDark,
        fontSize: 20,
          fontWeight: FontWeight.w700,
      ),
        iconTheme: const IconThemeData(color: textDark),
    ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: surfaceLight,
    ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
      foregroundColor: Colors.white,
      elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
        foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentColor, width: 2),
      ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textDark,
        contentTextStyle:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
    ),
  );
  }

  static ThemeData getDarkTheme(Color accentColor) {
    final accentLight = Color.lerp(accentColor, Colors.white, 0.3)!;
    
    return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: accentLight,
        secondary: accentColor,
        tertiary: accentColor,
      surface: surfaceDark,
        background: bgDark,
        onPrimary: bgDark,
      onSecondary: Colors.white,
        onSurface: textLight,
        onBackground: textLight,
    ),
      scaffoldBackgroundColor: bgDark,
      appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: accentColor,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: const TextStyle(
          color: textLight,
        fontSize: 20,
          fontWeight: FontWeight.w700,
      ),
        iconTheme: const IconThemeData(color: textLight),
    ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: surfaceDark,
    ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentLight,
        foregroundColor: bgDark,
      elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
          backgroundColor: accentLight,
          foregroundColor: bgDark,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardDark,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentLight, width: 2),
      ),
        hintStyle: const TextStyle(color: textMutedDark),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardDark,
        contentTextStyle:
            const TextStyle(color: textLight, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
    ),
  );
  }
}
