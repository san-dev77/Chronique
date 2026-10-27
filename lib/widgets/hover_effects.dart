import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Souleve un element au survol de la souris.
///
/// Sur mobile, aucun pointeur ne survole : le widget ne coute rien et ne
/// change rien. Sur desktop, c'est ce retour visuel qui fait la difference
/// entre une application portee et une application concue pour l'ecran.
class HoverLift extends StatefulWidget {
  final Widget child;
  final double scale;
  final double lift;
  final Color? glowColor;
  final BorderRadius borderRadius;
  final bool enabled;

  const HoverLift({
    super.key,
    required this.child,
    this.scale = 1.018,
    this.lift = 3,
    this.glowColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.enabled = true,
  });

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final glow = widget.glowColor ?? Theme.of(context).colorScheme.primary;
    final active = _hover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        transform: Matrix4.identity()
          ..translate(0.0, active ? -widget.lift : 0.0)
          ..scale(active ? widget.scale : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.26),
                    blurRadius: 26,
                    spreadRadius: -2,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Bouton icone avec etat de survol explicite, pour les barres d'outils.
class HoverIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final double size;

  const HoverIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.size = 20,
  });

  @override
  State<HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<HoverIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 420),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _hover
                  ? color.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(widget.icon, size: widget.size, color: color),
          ),
        ),
      ),
    );
  }
}
