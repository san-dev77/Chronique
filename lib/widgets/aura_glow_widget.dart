import 'dart:math';
import 'package:flutter/material.dart';

/// Particule individuelle pour l'effet aura
class _Particle {
  double x;       // Position X relative (0.0 - 1.0)
  double y;       // Position Y relative (0.0 - 1.0)
  double speed;   // Vitesse de montée
  double size;    // Taille
  double opacity; // Opacité
  double phase;   // Phase du mouvement sinusoïdal
  double amplitude; // Amplitude du mouvement latéral

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.phase,
    required this.amplitude,
  });
}

/// Widget qui dessine une aura énergétique animée avec particules montantes.
/// Effet Super Saiyan : halo pulsant + particules lumineuses flottantes.
class AuraGlowWidget extends StatefulWidget {
  final Widget child;
  final Color auraColor;
  final bool enabled;
  final double intensity;
  final BorderRadius borderRadius;

  const AuraGlowWidget({
    super.key,
    required this.child,
    required this.auraColor,
    this.enabled = true,
    this.intensity = 0.8,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
  });

  @override
  State<AuraGlowWidget> createState() => _AuraGlowWidgetState();
}

class _AuraGlowWidgetState extends State<AuraGlowWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _particleController;
  final List<_Particle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    // Animation de pulsation du halo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    // Animation des particules (boucle continue rapide)
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16000),
    );

    _initParticles();

    if (widget.enabled) {
      _pulseController.repeat(reverse: true);
      _particleController.repeat();
    }
  }

  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < 18; i++) {
      _particles.add(_createParticle());
    }
  }

  _Particle _createParticle({bool fromBottom = false}) {
    // Les particules naissent sur les bords (gauche, droite, bas)
    final side = _random.nextInt(3); // 0=gauche, 1=droite, 2=bas
    double x, y;
    switch (side) {
      case 0: // Gauche
        x = -0.05 + _random.nextDouble() * 0.15;
        y = 0.3 + _random.nextDouble() * 0.7;
        break;
      case 1: // Droite
        x = 0.85 + _random.nextDouble() * 0.2;
        y = 0.3 + _random.nextDouble() * 0.7;
        break;
      default: // Bas
        x = 0.1 + _random.nextDouble() * 0.8;
        y = 0.85 + _random.nextDouble() * 0.2;
    }
    if (fromBottom) {
      y = 0.9 + _random.nextDouble() * 0.15;
    }

    return _Particle(
      x: x,
      y: y,
      speed: 0.003 + _random.nextDouble() * 0.006,
      size: 1.5 + _random.nextDouble() * 3.0,
      opacity: 0.3 + _random.nextDouble() * 0.5,
      phase: _random.nextDouble() * 2 * pi,
      amplitude: 0.01 + _random.nextDouble() * 0.03,
    );
  }

  @override
  void didUpdateWidget(AuraGlowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
      _particleController.repeat();
    } else if (!widget.enabled && _pulseController.isAnimating) {
      _pulseController.stop();
      _particleController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _updateParticles() {
    for (int i = 0; i < _particles.length; i++) {
      final p = _particles[i];
      // Monter
      p.y -= p.speed;
      // Mouvement sinusoïdal latéral
      p.x += sin(p.phase + _particleController.value * 2 * pi * 3) * p.amplitude * 0.05;
      // Fade out en montant
      if (p.y < 0.2) {
        p.opacity *= 0.97;
      }
      // Respawn quand trop haut ou invisible
      if (p.y < -0.1 || p.opacity < 0.05) {
        _particles[i] = _createParticle(fromBottom: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _particleController]),
      builder: (context, child) {
        _updateParticles();
        final pulse = 0.55 + (_pulseController.value * 0.45);
        return CustomPaint(
          painter: _AuraGlowPainter(
            color: widget.auraColor,
            pulse: pulse,
            intensity: widget.intensity,
            borderRadius: widget.borderRadius,
            particles: _particles,
            isDark: isDark,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _AuraGlowPainter extends CustomPainter {
  final Color color;
  final double pulse;
  final double intensity;
  final BorderRadius borderRadius;
  final List<_Particle> particles;
  final bool isDark;

  _AuraGlowPainter({
    required this.color,
    required this.pulse,
    required this.intensity,
    required this.borderRadius,
    required this.particles,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final darkBoost = isDark ? 1.3 : 1.0;

    // Couche 1 : Halo externe massif et diffus
    final outerSpread = 22.0 * pulse * intensity;
    final outerRect = rrect.inflate(outerSpread);
    final outerPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 25.0 * pulse)
      ..color = color.withOpacity(0.22 * pulse * intensity * darkBoost);
    canvas.drawRRect(outerRect, outerPaint);

    // Couche 2 : Halo moyen intense
    final midSpread = 12.0 * pulse * intensity;
    final midRect = rrect.inflate(midSpread);
    final midPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 14.0 * pulse)
      ..color = color.withOpacity(0.35 * pulse * intensity * darkBoost);
    canvas.drawRRect(midRect, midPaint);

    // Couche 3 : Halo serré lumineux
    final tightSpread = 5.0 * pulse * intensity;
    final tightRect = rrect.inflate(tightSpread);
    final tightPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * pulse)
      ..color = color.withOpacity(0.3 * pulse * intensity * darkBoost);
    canvas.drawRRect(tightRect, tightPaint);

    // Couche 4 : Bordure lumineuse
    final borderPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * pulse)
      ..color = color.withOpacity(0.5 * pulse * intensity * darkBoost)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * pulse;
    canvas.drawRRect(rrect.inflate(1.5), borderPaint);

    // Couche 5 : Particules montantes
    _drawParticles(canvas, size);
  }

  void _drawParticles(Canvas canvas, Size size) {
    final darkBoost = isDark ? 1.4 : 1.0;

    for (final p in particles) {
      final px = p.x * size.width;
      final py = p.y * size.height;

      // Particule principale (point lumineux)
      final particlePaint = Paint()
        ..color = color.withOpacity((p.opacity * intensity * darkBoost).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 1.5);
      canvas.drawCircle(Offset(px, py), p.size * intensity, particlePaint);

      // Halo de la particule (glow autour)
      final haloPaint = Paint()
        ..color = color.withOpacity((p.opacity * 0.3 * intensity * darkBoost).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 4.0);
      canvas.drawCircle(Offset(px, py), p.size * 2.5 * intensity, haloPaint);
    }
  }

  @override
  bool shouldRepaint(_AuraGlowPainter oldDelegate) => true;
}
