import 'package:flutter/material.dart';

/// Configuration des auras émotionnelles pour les chroniques
class NoteMood {
  final String key;
  final IconData icon;
  final String label;
  final Color defaultColor;

  const NoteMood._({
    required this.key,
    required this.icon,
    required this.label,
    required this.defaultColor,
  });

  static const serene = NoteMood._(
    key: 'serene', icon: Icons.water_drop_outlined, label: 'Serein',
    defaultColor: Color(0xFF87CEEB),
  );
  static const joyful = NoteMood._(
    key: 'joyful', icon: Icons.wb_sunny_outlined, label: 'Joyeux',
    defaultColor: Color(0xFFFFD700),
  );
  static const melancholy = NoteMood._(
    key: 'melancholy', icon: Icons.grain_rounded, label: 'Mélancolique',
    defaultColor: Color(0xFF6A7B8B),
  );
  static const dark = NoteMood._(
    key: 'dark', icon: Icons.dark_mode_outlined, label: 'Dark',
    defaultColor: Color(0xFF4A0E4E),
  );
  static const pensive = NoteMood._(
    key: 'pensive', icon: Icons.psychology_outlined, label: 'Pensif',
    defaultColor: Color(0xFF3F51B5),
  );
  static const lost = NoteMood._(
    key: 'lost', icon: Icons.explore_off_outlined, label: 'Perdu',
    defaultColor: Color(0xFF9E9E9E),
  );
  static const passionate = NoteMood._(
    key: 'passionate', icon: Icons.local_fire_department_outlined, label: 'Passionné',
    defaultColor: Color(0xFFFF5722),
  );
  static const dreamy = NoteMood._(
    key: 'dreamy', icon: Icons.nightlight_outlined, label: 'Rêveur',
    defaultColor: Color(0xFFB39DDB),
  );
  static const angry = NoteMood._(
    key: 'angry', icon: Icons.flash_on_rounded, label: 'Colère',
    defaultColor: Color(0xFFD32F2F),
  );
  static const lonely = NoteMood._(
    key: 'lonely', icon: Icons.person_outline_rounded, label: 'Solitude',
    defaultColor: Color(0xFF1A237E),
  );
  static const despair = NoteMood._(
    key: 'despair', icon: Icons.heart_broken_outlined, label: 'Désespoir',
    defaultColor: Color(0xFF212121),
  );
  static const empty = NoteMood._(
    key: 'empty', icon: Icons.circle_outlined, label: 'Vide',
    defaultColor: Colors.transparent,
  );

  static const List<NoteMood> all = [
    serene, joyful, melancholy, dark, pensive, lost,
    passionate, dreamy, angry, lonely, despair, empty,
  ];

  static NoteMood? fromKey(String? key) {
    if (key == null) return null;
    try {
      return all.firstWhere((m) => m.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Retourne la couleur effective (custom override ou défaut)
  static Color getEffectiveColor(String? moodKey, int? moodColorValue) {
    if (moodKey == null) return Colors.transparent;
    if (moodColorValue != null) return Color(moodColorValue);
    final mood = fromKey(moodKey);
    return mood?.defaultColor ?? Colors.transparent;
  }

  /// Vérifie si l'aura doit afficher un halo
  static bool hasGlow(String? moodKey) {
    return moodKey != null && moodKey != 'empty';
  }
}
