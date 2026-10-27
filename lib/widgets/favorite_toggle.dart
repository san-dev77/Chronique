import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Cœur de mise en favori, avec sa petite fête.
///
/// Composant reutilisable : la mise en favori se fait depuis la grille, la
/// lecture d'une note et l'editeur. L'animation doit etre la meme partout,
/// sinon le geste ne se reconnait pas d'un ecran a l'autre.
class FavoriteToggle extends StatefulWidget {
  final bool isFavorite;
  final ValueChanged<bool> onChanged;
  final double size;
  final Color activeColor;
  final Color inactiveColor;
  final String? tooltip;

  const FavoriteToggle({
    super.key,
    required this.isFavorite,
    required this.onChanged,
    this.size = 22,
    this.activeColor = const Color(0xFFE05252),
    this.inactiveColor = const Color(0xFF94A3B8),
    this.tooltip,
  });

  @override
  State<FavoriteToggle> createState() => _FavoriteToggleState();
}

class _FavoriteToggleState extends State<FavoriteToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  bool _hover = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    final next = !widget.isFavorite;
    widget.onChanged(next);
    if (next) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse(from: _controller.value.clamp(0.0, 1.0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.isFavorite;
    final color = on
        ? widget.activeColor
        : (_hover ? widget.activeColor : widget.inactiveColor);

    Widget core = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        // Le cœur depasse sa taille puis revient : c'est ce petit rebond qui
        // rend le geste satisfaisant.
        double scale = 1;
        if (t > 0) {
          scale = 1 + sin(t * pi) * 0.42;
        }
        if (_hover && t == 0) scale = 1.12;

        return CustomPaint(
          painter: t > 0 && t < 1
              ? _BurstPainter(progress: t, color: widget.activeColor)
              : null,
          child: Transform.scale(
            scale: scale,
            child: Icon(
              on ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
              size: widget.size,
              color: color,
            ),
          ),
        );
      },
    );

    core = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _toggle,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.all(widget.size * 0.3),
          child: core,
        ),
      ),
    );

    if (widget.tooltip == null) return core;
    return Tooltip(
      message: widget.tooltip!,
      waitDuration: const Duration(milliseconds: 450),
      child: core,
    );
  }
}

/// Gerbe d'eclats qui part du cœur au moment ou on l'allume.
class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.longestSide * 1.5;

    // Anneau qui s'ouvre et s'efface
    final ringT = Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final ringAlpha = (1 - ringT).clamp(0.0, 1.0) * 0.55;
    if (ringAlpha > 0.01) {
      canvas.drawCircle(
        center,
        maxRadius * 0.35 + maxRadius * 0.55 * ringT,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2 * (1 - ringT) + 0.4
          ..color = color.withValues(alpha: ringAlpha),
      );
    }

    // Huit eclats radiaux
    const count = 8;
    final t = Curves.easeOutQuart.transform(progress.clamp(0.0, 1.0));
    final alpha = (1 - t).clamp(0.0, 1.0) * 0.9;
    if (alpha <= 0.01) return;

    final paint = Paint()..color = color.withValues(alpha: alpha);
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * 2 * pi - pi / 2;
      final distance = maxRadius * 0.30 + maxRadius * 0.5 * t;
      final p = center + Offset(cos(angle), sin(angle)) * distance;
      canvas.drawCircle(p, 2.0 * (1 - t) + 0.6, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.progress != progress || old.color != color;
}

/// Variante compacte posee sur une image : pastille sombre + cœur.
class FavoriteBubble extends StatelessWidget {
  final bool isFavorite;
  final ValueChanged<bool> onChanged;
  final bool onImage;
  final Color tint;

  const FavoriteBubble({
    super.key,
    required this.isFavorite,
    required this.onChanged,
    this.onImage = false,
    this.tint = const Color(0xFF94A3B8),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: (onImage ? Colors.black : tint).withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: FavoriteToggle(
        isFavorite: isFavorite,
        onChanged: onChanged,
        size: 20,
        inactiveColor: onImage ? Colors.white : tint,
        tooltip: isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris',
      ),
    );
  }
}
