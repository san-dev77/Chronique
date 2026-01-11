import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gerer la couleur d'accent personnalisee de l'app
class AccentColorService extends ChangeNotifier {
  static final AccentColorService _instance = AccentColorService._internal();
  static AccentColorService get instance => _instance;
  
  AccentColorService._internal();

  static const String _colorKey = 'accent_color';
  
  // Couleur par defaut
  Color _accentColor = const Color(0xFF4A90D9); // Sky Blue
  
  Color get accentColor => _accentColor;
  
  // Couleurs predefinies disponibles
  static final List<AccentColorOption> availableColors = [
    AccentColorOption('Bleu Ciel', const Color(0xFF4A90D9)),
    AccentColorOption('Bleu Ocean', const Color(0xFF2196F3)),
    AccentColorOption('Bleu Nuit', const Color(0xFF3F51B5)),
    AccentColorOption('Violet', const Color(0xFF9C27B0)),
    AccentColorOption('Rose', const Color(0xFFE91E63)),
    AccentColorOption('Rouge', const Color(0xFFF44336)),
    AccentColorOption('Orange', const Color(0xFFFF9800)),
    AccentColorOption('Ambre', const Color(0xFFFFC107)),
    AccentColorOption('Vert', const Color(0xFF4CAF50)),
    AccentColorOption('Emeraude', const Color(0xFF009688)),
    AccentColorOption('Cyan', const Color(0xFF00BCD4)),
    AccentColorOption('Gris', const Color(0xFF607D8B)),
  ];

  /// Initialise le service en chargeant la couleur sauvegardee
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt(_colorKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }
    notifyListeners();
  }

  /// Change la couleur d'accent et la sauvegarde
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_colorKey, color.value);
  }

  /// Retourne une version plus claire de la couleur d'accent
  Color get accentLight => Color.lerp(_accentColor, Colors.white, 0.3)!;
  
  /// Retourne une version plus foncee de la couleur d'accent
  Color get accentDark => Color.lerp(_accentColor, Colors.black, 0.2)!;
  
  /// Retourne une version tres pale de la couleur d'accent
  Color get accentPale => _accentColor.withOpacity(0.1);
}

class AccentColorOption {
  final String name;
  final Color color;
  
  AccentColorOption(this.name, this.color);
}
