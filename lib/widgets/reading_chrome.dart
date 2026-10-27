import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Barre de progression de lecture.
///
/// Un trait de deux pixels en haut de l'ecran. On sait ou l'on en est dans
/// une chronique longue sans avoir a chercher l'ascenseur, et il disparait
/// quand il n'y a rien a faire defiler.
class ReadingProgress extends StatelessWidget {
  final double value;
  final Color accent;

  const ReadingProgress({super.key, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: AppMotion.medium,
        opacity: value > 0.001 && value < 0.999 ? 1 : 0,
        child: SizedBox(
          height: 2.5,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.65),
                      accent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton d'outil des ecrans de lecture.
class ToolButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  final Color? activeColor;
  final bool active;

  const ToolButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
    this.activeColor,
    this.active = false,
  });

  @override
  State<ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<ToolButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.active
        ? (widget.activeColor ?? AppTheme.skyBlue)
        : widget.color;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 380),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hover
                  ? tint.withValues(alpha: 0.14)
                  : widget.color.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.icon, color: tint, size: 20),
          ),
        ),
      ),
    );
  }
}

/// Petite etiquette de contexte : une icone, un mot.
///
/// Sert aux metadonnees d'une chronique — date, duree de lecture, aura.
/// Volontairement discrete : ce sont des reperes, pas des boutons.
class MetaPill extends StatelessWidget {
  final IconData? icon;
  final Color? dot;
  final String label;
  final Color textColor;
  final Color? tint;

  const MetaPill({
    super.key,
    this.icon,
    this.dot,
    required this.label,
    required this.textColor,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint ?? textColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: tint == null ? 0.065 : 0.13),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: base.withValues(alpha: tint == null ? 0 : 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot != null)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: dot,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: dot!.withValues(alpha: 0.8), blurRadius: 5),
                ],
              ),
            )
          else if (icon != null) ...[
            Icon(icon, size: 12.5, color: base.withValues(alpha: 0.75)),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: tint == null
                  ? textColor.withValues(alpha: 0.65)
                  : Color.lerp(tint, textColor, 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Duree de lecture estimee, en minutes.
///
/// Deux cents mots par minute : la moyenne admise pour une lecture suivie.
/// Afficher « 4 min » evite d'ouvrir une chronique sans savoir si l'on a le
/// temps de la lire.
int readingMinutes(String text) {
  final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return (words.length / 200).ceil().clamp(1, 999);
}
