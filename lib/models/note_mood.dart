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

  // ------------------------------------------------------------ mélancolie

  static const vagueALame = NoteMood._(
    key: 'vague_a_lame',
    icon: Icons.waves_outlined,
    label: 'Le vague à l\'âme',
    defaultColor: Color(0xFF6B73FF),
  );
  static const dark = NoteMood._(
    key: 'dark',
    icon: Icons.dark_mode_outlined,
    label: 'Dark',
    defaultColor: Color(0xFF4C2FA8),
  );
  static const vide = NoteMood._(
    key: 'vide',
    icon: Icons.circle_outlined,
    label: 'Vide',
    defaultColor: Color(0xFF8E8E93),
  );
  static const brise = NoteMood._(
    key: 'brise',
    icon: Icons.heart_broken_outlined,
    label: 'Brisé',
    defaultColor: Color(0xFFB91C1C),
  );
  static const perdu = NoteMood._(
    key: 'perdu',
    icon: Icons.explore_off_outlined,
    label: 'Perdu',
    defaultColor: Color(0xFF6B7280),
  );

  // ----------------------------------------------------------------- calme

  static const serein = NoteMood._(
    key: 'serein',
    icon: Icons.spa_outlined,
    label: 'Serein',
    defaultColor: Color(0xFF14B8A6),
  );
  static const tendre = NoteMood._(
    key: 'tendre',
    icon: Icons.favorite_border_rounded,
    label: 'Tendre',
    defaultColor: Color(0xFFF472B6),
  );
  static const reverie = NoteMood._(
    key: 'reverie',
    icon: Icons.bedtime_outlined,
    label: 'Rêverie',
    defaultColor: Color(0xFFA78BFA),
  );

  // ---------------------------------------------------------------- ardeur

  static const elan = NoteMood._(
    key: 'elan',
    icon: Icons.bolt_outlined,
    label: 'Élan',
    defaultColor: Color(0xFFF59E0B),
  );
  static const colere = NoteMood._(
    key: 'colere',
    icon: Icons.local_fire_department_outlined,
    label: 'Colère',
    defaultColor: Color(0xFFDC2626),
  );
  static const nostalgie = NoteMood._(
    key: 'nostalgie',
    icon: Icons.auto_stories_outlined,
    label: 'Nostalgie',
    defaultColor: Color(0xFFC2833A),
  );
  static const espoir = NoteMood._(
    key: 'espoir',
    icon: Icons.wb_twilight_rounded,
    label: 'Espoir',
    defaultColor: Color(0xFF38BDF8),
  );

  static const List<NoteMood> all = [
    vagueALame,
    dark,
    vide,
    brise,
    perdu,
    serein,
    tendre,
    reverie,
    elan,
    colere,
    nostalgie,
    espoir,
  ];

  /// Regroupement utilisé par le sélecteur d'aura.
  static const Map<String, List<NoteMood>> families = {
    'Mélancolie': [vagueALame, dark, vide, brise, perdu],
    'Calme': [serein, tendre, reverie],
    'Ardeur': [elan, colere, nostalgie, espoir],
  };

  /// Palette de teintes proposée pour personnaliser une aura.
  static const List<Color> palette = [
    Color(0xFF6B73FF),
    Color(0xFF4C2FA8),
    Color(0xFF7C3AED),
    Color(0xFFA78BFA),
    Color(0xFF38BDF8),
    Color(0xFF0EA5E9),
    Color(0xFF0891B2),
    Color(0xFF14B8A6),
    Color(0xFF10B981),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
    Color(0xFFF59E0B),
    Color(0xFFC2833A),
    Color(0xFFEA580C),
    Color(0xFFDC2626),
    Color(0xFFB91C1C),
    Color(0xFFEC4899),
    Color(0xFFF472B6),
    Color(0xFFE879F9),
    Color(0xFF64748B),
    Color(0xFF8E8E93),
    Color(0xFF334155),
    Color(0xFFF8FAFC),
    Color(0xFFFCD34D),
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

    // Gérer les moods personnalisés
    if (moodKey.startsWith('custom:')) {
      return const Color(0xFFA78BFA);
    }

    final mood = fromKey(moodKey);
    return mood?.defaultColor ?? Colors.transparent;
  }

  /// Clé d'une aura sans humeur nommée : on veut juste une couleur.
  static const String freeKey = 'custom:';

  /// Construit la clé d'une humeur écrite par l'utilisateur.
  static String customKey(String name) => 'custom:${name.trim()}';

  /// Vrai si l'aura n'est qu'une couleur, sans nom.
  static bool isFree(String? moodKey) => moodKey == freeKey;

  /// Vrai pour une humeur écrite par l'utilisateur (nommée ou non).
  static bool isCustom(String? moodKey) =>
      moodKey != null && moodKey.startsWith('custom:');

  /// Retourne le label d'affichage pour un mood (y compris personnalisés)
  static String getDisplayLabel(String? moodKey) {
    if (moodKey == null) return '';

    // Gérer les moods personnalisés
    if (moodKey.startsWith('custom:')) {
      final name = moodKey.substring(7).trim();
      return name.isEmpty ? 'Aura' : name;
    }

    final mood = fromKey(moodKey);
    return mood?.label ?? '';
  }

  /// Icône d'affichage, y compris pour un mood personnalisé.
  static IconData getDisplayIcon(String? moodKey) {
    if (moodKey == null) return Icons.auto_awesome_outlined;
    if (moodKey.startsWith('custom:')) return Icons.auto_awesome_rounded;
    return fromKey(moodKey)?.icon ?? Icons.auto_awesome_rounded;
  }

  /// Vérifie si l'aura doit afficher un halo
  static bool hasGlow(String? moodKey) {
    return moodKey != null;
  }
}
