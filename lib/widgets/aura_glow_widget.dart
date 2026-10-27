import 'dart:math';
import 'package:flutter/material.dart';
import '../models/note_mood.dart';

/// Comportement visuel d'une aura.
///
/// Chaque humeur ne se distingue plus seulement par sa couleur mais par sa
/// maniere de bouger : c'est ce qui donne le sentiment que la note « respire »
/// d'une facon qui lui est propre.
enum AuraBehaviour {
  /// Le vague a l'ame : une houle lente, des particules qui montent en ondulant.
  swell,

  /// Dark : une brume dense et basse, des particules qui retombent.
  mist,

  /// Vide : un halo tres diffus, presque immobile, quelques poussieres.
  hollow,

  /// Brise : une pulsation arythmique, des eclats nets et rapides.
  fracture,

  /// Perdu : une derive sans direction, un halo qui vacille.
  drift,

  /// Serein, tendre : des bulles qui s'epanouissent depuis le coeur.
  bloom,

  /// Elan : des etincelles rapides qui filent vers le haut en laissant une
  /// trainee.
  spark,

  /// Colere, nostalgie : des braises qui montent en scintillant.
  ember,

  /// Reverie, espoir : des lucioles sur des orbites elliptiques.
  orbit,
}

class AuraSpec {
  final AuraBehaviour behaviour;
  final int particleCount;
  final double particleSpeed;
  final double particleSize;
  final double blurRadius;
  final double haloAlpha;
  final double rimAlpha;
  final double pulseAmount;
  final double period;

  const AuraSpec({
    required this.behaviour,
    required this.particleCount,
    required this.particleSpeed,
    required this.particleSize,
    required this.blurRadius,
    required this.haloAlpha,
    required this.rimAlpha,
    required this.pulseAmount,
    required this.period,
  });

  static const _swell = AuraSpec(
    behaviour: AuraBehaviour.swell,
    particleCount: 10,
    particleSpeed: 0.055,
    particleSize: 2.4,
    blurRadius: 22,
    haloAlpha: 0.34,
    rimAlpha: 0.55,
    pulseAmount: 0.30,
    period: 3.6,
  );

  static const _mist = AuraSpec(
    behaviour: AuraBehaviour.mist,
    particleCount: 12,
    particleSpeed: 0.032,
    particleSize: 3.4,
    blurRadius: 30,
    haloAlpha: 0.42,
    rimAlpha: 0.34,
    pulseAmount: 0.16,
    period: 5.4,
  );

  static const _hollow = AuraSpec(
    behaviour: AuraBehaviour.hollow,
    particleCount: 5,
    particleSpeed: 0.016,
    particleSize: 1.8,
    blurRadius: 34,
    haloAlpha: 0.22,
    rimAlpha: 0.20,
    pulseAmount: 0.09,
    period: 7.5,
  );

  static const _fracture = AuraSpec(
    behaviour: AuraBehaviour.fracture,
    particleCount: 9,
    particleSpeed: 0.115,
    particleSize: 1.9,
    blurRadius: 16,
    haloAlpha: 0.36,
    rimAlpha: 0.72,
    pulseAmount: 0.42,
    period: 2.3,
  );

  static const _drift = AuraSpec(
    behaviour: AuraBehaviour.drift,
    particleCount: 8,
    particleSpeed: 0.026,
    particleSize: 2.2,
    blurRadius: 26,
    haloAlpha: 0.28,
    rimAlpha: 0.30,
    pulseAmount: 0.20,
    period: 4.8,
  );

  static const _bloomCalm = AuraSpec(
    behaviour: AuraBehaviour.bloom,
    particleCount: 9,
    particleSpeed: 0.030,
    particleSize: 2.6,
    blurRadius: 26,
    haloAlpha: 0.30,
    rimAlpha: 0.40,
    pulseAmount: 0.22,
    period: 5.0,
  );

  static const _bloomTender = AuraSpec(
    behaviour: AuraBehaviour.bloom,
    particleCount: 12,
    particleSpeed: 0.042,
    particleSize: 2.2,
    blurRadius: 24,
    haloAlpha: 0.34,
    rimAlpha: 0.46,
    pulseAmount: 0.28,
    period: 4.0,
  );

  static const _spark = AuraSpec(
    behaviour: AuraBehaviour.spark,
    particleCount: 14,
    particleSpeed: 0.155,
    particleSize: 1.7,
    blurRadius: 18,
    haloAlpha: 0.32,
    rimAlpha: 0.66,
    pulseAmount: 0.34,
    period: 2.0,
  );

  static const _emberSlow = AuraSpec(
    behaviour: AuraBehaviour.ember,
    particleCount: 13,
    particleSpeed: 0.048,
    particleSize: 2.3,
    blurRadius: 24,
    haloAlpha: 0.33,
    rimAlpha: 0.42,
    pulseAmount: 0.24,
    period: 4.4,
  );

  static const _emberFierce = AuraSpec(
    behaviour: AuraBehaviour.ember,
    particleCount: 18,
    particleSpeed: 0.098,
    particleSize: 2.1,
    blurRadius: 20,
    haloAlpha: 0.40,
    rimAlpha: 0.70,
    pulseAmount: 0.38,
    period: 2.6,
  );

  static const _orbitDream = AuraSpec(
    behaviour: AuraBehaviour.orbit,
    particleCount: 10,
    particleSpeed: 0.055,
    particleSize: 2.0,
    blurRadius: 28,
    haloAlpha: 0.30,
    rimAlpha: 0.38,
    pulseAmount: 0.20,
    period: 5.6,
  );

  static const _orbitHope = AuraSpec(
    behaviour: AuraBehaviour.orbit,
    particleCount: 12,
    particleSpeed: 0.078,
    particleSize: 2.2,
    blurRadius: 24,
    haloAlpha: 0.34,
    rimAlpha: 0.52,
    pulseAmount: 0.26,
    period: 3.8,
  );

  static AuraSpec forMood(String? moodKey) {
    switch (moodKey) {
      case 'vague_a_lame':
        return _swell;
      case 'dark':
        return _mist;
      case 'vide':
        return _hollow;
      case 'brise':
        return _fracture;
      case 'perdu':
        return _drift;
      case 'serein':
        return _bloomCalm;
      case 'tendre':
        return _bloomTender;
      case 'reverie':
        return _orbitDream;
      case 'espoir':
        return _orbitHope;
      case 'elan':
        return _spark;
      case 'colere':
        return _emberFierce;
      case 'nostalgie':
        return _emberSlow;
      default:
        return _swell;
    }
  }

  /// Courte description, utilisee par le selecteur d'aura.
  static String describe(String? moodKey) {
    switch (moodKey) {
      case 'vague_a_lame':
        return 'Une houle lente, qui monte et redescend';
      case 'dark':
        return 'Une brume dense qui retombe';
      case 'vide':
        return 'Un halo diffus, presque immobile';
      case 'brise':
        return 'Une pulsation irrégulière, des éclats';
      case 'perdu':
        return 'Une dérive sans direction';
      case 'serein':
        return 'Des bulles qui s\'épanouissent, sans hâte';
      case 'tendre':
        return 'Une floraison douce, tout en rondeur';
      case 'reverie':
        return 'Des lucioles sur des orbites lentes';
      case 'espoir':
        return 'Une ronde lumineuse qui s\'élève';
      case 'elan':
        return 'Des étincelles qui filent vers le haut';
      case 'colere':
        return 'Des braises vives, un souffle court';
      case 'nostalgie':
        return 'Des braises qui montent en scintillant';
      default:
        return 'Une présence discrète autour de la note';
    }
  }
}

/// Particule decrite analytiquement : sa position se calcule a partir du temps,
/// elle n'est jamais mutee. L'ancienne version modifiait la liste pendant
/// `build`, ce qui rendait le rendu dependant du nombre de repeints.
class _Seed {
  final double x0;
  final double y0;
  final double speed;
  final double size;
  final double phase;
  final double amplitude;
  final double freq;

  const _Seed({
    required this.x0,
    required this.y0,
    required this.speed,
    required this.size,
    required this.phase,
    required this.amplitude,
    required this.freq,
  });
}

/// Halo anime autour d'une note.
///
/// [animated] a false rend une image fixe : c'est ce qu'on utilise dans les
/// grilles, ou dix auras animees en continu coutaient plus cher que tout le
/// reste de l'ecran. L'animation est reservee aux endroits ou on la regarde
/// vraiment : lecture d'une note et choix de l'aura.
class AuraGlowWidget extends StatefulWidget {
  final Widget child;
  final Color auraColor;
  final bool enabled;
  final double intensity;
  final BorderRadius borderRadius;
  final String? moodKey;
  final bool animated;

  const AuraGlowWidget({
    super.key,
    required this.child,
    required this.auraColor,
    this.enabled = true,
    this.intensity = 0.8,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.moodKey,
    this.animated = true,
  });

  @override
  State<AuraGlowWidget> createState() => _AuraGlowWidgetState();
}

class _AuraGlowWidgetState extends State<AuraGlowWidget>
    with SingleTickerProviderStateMixin {
  static const int _cycleSeconds = 24;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: _cycleSeconds),
  );

  late List<_Seed> _seeds;
  late AuraSpec _spec;

  @override
  void initState() {
    super.initState();
    _spec = AuraSpec.forMood(widget.moodKey);
    _seeds = _buildSeeds(_spec);
    _syncTicker();
  }

  @override
  void didUpdateWidget(AuraGlowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moodKey != widget.moodKey) {
      _spec = AuraSpec.forMood(widget.moodKey);
      _seeds = _buildSeeds(_spec);
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.animated != widget.animated) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    final shouldRun = widget.enabled && widget.animated;
    if (shouldRun && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldRun && _controller.isAnimating) {
      _controller.stop();
    }
  }

  List<_Seed> _buildSeeds(AuraSpec spec) {
    // Graine fixe : deux notes de la meme humeur partagent la meme signature
    // visuelle, et le rendu ne saute pas d'un build a l'autre.
    final random = Random(spec.behaviour.index * 7919 + 13);
    return List.generate(spec.particleCount, (_) {
      return _Seed(
        x0: random.nextDouble(),
        y0: random.nextDouble(),
        speed: spec.particleSpeed * (0.6 + random.nextDouble() * 0.8),
        size: spec.particleSize * (0.7 + random.nextDouble() * 0.7),
        phase: random.nextDouble() * 2 * pi,
        amplitude: 0.012 + random.nextDouble() * 0.045,
        freq: 0.35 + random.nextDouble() * 0.8,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final animate = widget.animated && !reduceMotion;

    if (!animate) {
      if (_controller.isAnimating) _controller.stop();
      return RepaintBoundary(
        child: CustomPaint(
          painter: _AuraPainter(
            color: widget.auraColor,
            time: 6.2, // instant fige choisi pour un halo genereux
            spec: _spec,
            seeds: _seeds,
            intensity: widget.intensity,
            borderRadius: widget.borderRadius,
            isDark: isDark,
          ),
          child: widget.child,
        ),
      );
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _AuraPainter(
              color: widget.auraColor,
              time: _controller.value * _cycleSeconds,
              spec: _spec,
              seeds: _seeds,
              intensity: widget.intensity,
              borderRadius: widget.borderRadius,
              isDark: isDark,
            ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  final Color color;
  final double time;
  final AuraSpec spec;
  final List<_Seed> seeds;
  final double intensity;
  final BorderRadius borderRadius;
  final bool isDark;

  const _AuraPainter({
    required this.color,
    required this.time,
    required this.spec,
    required this.seeds,
    required this.intensity,
    required this.borderRadius,
    required this.isDark,
  });

  /// Battement propre a l'humeur, dans [0, 1].
  double get _pulse {
    final t = time / spec.period * 2 * pi;
    switch (spec.behaviour) {
      case AuraBehaviour.fracture:
        // Deux periodes incommensurables : le rythme ne se boucle jamais tout
        // a fait, l'oeil percoit une arythmie.
        final a = sin(t);
        final b = sin(t * 1.618 + 1.1);
        return (0.5 + 0.32 * a + 0.18 * b).clamp(0.0, 1.0);
      case AuraBehaviour.drift:
        final a = sin(t);
        final wobble = sin(t * 0.37) * 0.25;
        return (0.5 + 0.4 * a + wobble * 0.4).clamp(0.0, 1.0);
      case AuraBehaviour.hollow:
        return 0.5 + 0.5 * sin(t) * 0.55;
      case AuraBehaviour.ember:
        // Souffle irregulier : la braise ne pulse pas comme un metronome.
        final a = sin(t);
        final flicker = sin(t * 2.7 + 0.6) * 0.18;
        return (0.5 + 0.36 * a + flicker).clamp(0.0, 1.0);
      case AuraBehaviour.spark:
        // Montee franche, retombee douce.
        final v = sin(t);
        return (0.5 + 0.5 * (v > 0 ? pow(v, 0.55).toDouble() : v * 0.6))
            .clamp(0.0, 1.0);
      default:
        return 0.5 + 0.5 * sin(t);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    final pulse = _pulse;
    final boost = isDark ? 1.25 : 0.9;
    final amp = 1 - spec.pulseAmount + spec.pulseAmount * pulse;

    // Un seul flou pour le halo. L'ancienne version en empilait quatre, ce qui
    // multipliait par quatre le passage le plus couteux du rendu.
    final haloAlpha =
        (spec.haloAlpha * intensity * boost * amp).clamp(0.0, 1.0);
    if (haloAlpha > 0.01) {
      final halo = Paint()
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, spec.blurRadius * (0.75 + 0.25 * pulse))
        ..color = color.withValues(alpha: haloAlpha);
      canvas.drawRRect(rrect.inflate(spec.blurRadius * 0.35 * amp), halo);
    }

    // Liseré net : c'est lui qui « dessine » la note, sans flou donc gratuit.
    final rimAlpha = (spec.rimAlpha * intensity * boost * amp).clamp(0.0, 1.0);
    if (rimAlpha > 0.01) {
      final rim = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 + 0.8 * pulse
        ..color = color.withValues(alpha: rimAlpha);
      canvas.drawRRect(rrect.deflate(0.7), rim);
    }

    _paintParticles(canvas, size, pulse, boost);
  }

  void _paintParticles(Canvas canvas, Size size, double pulse, double boost) {
    canvas.save();
    canvas.clipRRect(borderRadius.toRRect(Offset.zero & size).inflate(10));

    for (final seed in seeds) {
      final travel = time * seed.speed;

      double y;
      double x = seed.x0;
      double trail = 0; // longueur de trainee, en fraction de hauteur

      switch (spec.behaviour) {
        case AuraBehaviour.mist:
          y = (seed.y0 + travel) % 1.25 - 0.12;
          x += sin(time * seed.freq * 0.5 + seed.phase) * seed.amplitude;
          break;

        case AuraBehaviour.drift:
          y = (seed.y0 + travel * 0.35) % 1.2 - 0.1;
          x += sin(time * seed.freq * 0.8 + seed.phase) * seed.amplitude * 3.2;
          break;

        case AuraBehaviour.fracture:
          y = 1.1 - ((seed.y0 + travel) % 1.25);
          x += sin(seed.phase) * seed.amplitude * 0.4;
          break;

        case AuraBehaviour.hollow:
          y = (seed.y0 + travel) % 1.2 - 0.1;
          x += sin(time * seed.freq * 0.25 + seed.phase) * seed.amplitude * 0.6;
          break;

        case AuraBehaviour.swell:
          y = 1.1 - ((seed.y0 + travel) % 1.25);
          x += sin(time * seed.freq + seed.phase) * seed.amplitude * 2.0;
          break;

        case AuraBehaviour.spark:
          // File vers le haut, presque droit, avec une trainee.
          y = 1.12 - ((seed.y0 + travel) % 1.3);
          x += sin(time * seed.freq * 2.4 + seed.phase) * seed.amplitude * 0.9;
          trail = 0.055 + seed.size * 0.012;
          break;

        case AuraBehaviour.ember:
          // Monte en zigzaguant, comme portee par un courant d'air chaud.
          y = 1.1 - ((seed.y0 + travel) % 1.28);
          x += sin(time * seed.freq * 1.6 + seed.phase) * seed.amplitude * 2.6;
          x += sin(time * seed.freq * 0.4 + seed.phase * 2) * seed.amplitude;
          break;

        case AuraBehaviour.bloom:
          // S'ecarte du coeur en spirale douce, puis s'efface.
          final phase = (seed.y0 + travel) % 1.0;
          final angle = seed.phase + phase * 1.4;
          final radius = 0.08 + phase * 0.44;
          x = 0.5 + cos(angle) * radius;
          y = 0.5 + sin(angle) * radius * 0.82;
          break;

        case AuraBehaviour.orbit:
          // Orbite elliptique inclinee, chacune la sienne.
          final angle = seed.phase + time * seed.speed * 6.0;
          final rx = 0.20 + seed.amplitude * 5.5;
          final ry = rx * (0.42 + seed.x0 * 0.35);
          final tilt = seed.y0 * pi;
          final ox = cos(angle) * rx;
          final oy = sin(angle) * ry;
          x = 0.5 + ox * cos(tilt) - oy * sin(tilt);
          y = 0.5 + ox * sin(tilt) + oy * cos(tilt);
          break;
      }

      // Fondu : aux extremites du parcours, ou vers le bord pour les
      // comportements centres.
      double fade;
      if (spec.behaviour == AuraBehaviour.bloom) {
        final phase = (seed.y0 + travel) % 1.0;
        fade = (sin(phase * pi)).clamp(0.0, 1.0);
      } else if (spec.behaviour == AuraBehaviour.orbit) {
        fade = 1.0;
      } else {
        final edge = min(y, 1 - y);
        fade = (edge / 0.22).clamp(0.0, 1.0);
      }
      if (fade <= 0.02) continue;

      // Scintillement propre a chaque particule : sans lui, l'ensemble
      // ressemble a une nappe uniforme qui glisse.
      final twinkle =
          0.62 + 0.38 * sin(time * (1.6 + seed.freq * 2.2) + seed.phase * 3);

      final alpha = (0.60 * fade * twinkle * intensity * boost *
              (0.72 + 0.28 * pulse))
          .clamp(0.0, 1.0);
      if (alpha < 0.015) continue;

      final px = x * size.width;
      final py = y * size.height;
      final radius = seed.size * (0.85 + 0.3 * pulse);

      // Trainee des etincelles : un segment vers le bas, d'ou elles viennent.
      if (trail > 0) {
        canvas.drawLine(
          Offset(px, py),
          Offset(px, py + trail * size.height),
          Paint()
            ..color = color.withValues(alpha: alpha * 0.30)
            ..strokeWidth = radius * 0.9
            ..strokeCap = StrokeCap.round,
        );
      }

      // Coeur net : un point lumineux se lit mieux qu'une tache floue.
      canvas.drawCircle(
        Offset(px, py),
        radius,
        Paint()..color = color.withValues(alpha: alpha),
      );

      // Point blanc au centre des particules les plus vives : c'est ce qui
      // donne l'impression qu'elles emettent de la lumiere.
      if (alpha > 0.34) {
        canvas.drawCircle(
          Offset(px, py),
          radius * 0.42,
          Paint()
            ..color = Colors.white.withValues(alpha: (alpha - 0.34) * 0.85),
        );
      }

      // Halo court, un seul flou de petit rayon donc peu couteux.
      canvas.drawCircle(
        Offset(px, py),
        radius * 2.6,
        Paint()
          ..color = color.withValues(alpha: alpha * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter old) {
    return old.time != time ||
        old.color != color ||
        old.intensity != intensity ||
        old.spec != spec ||
        old.isDark != isDark;
  }
}

/// Pastille de couleur animee, pour le selecteur d'aura.
class AuraOrb extends StatelessWidget {
  final String? moodKey;
  final Color color;
  final double size;
  final bool active;

  const AuraOrb({
    super.key,
    required this.moodKey,
    required this.color,
    this.size = 46,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final mood = NoteMood.fromKey(moodKey);
    return AuraGlowWidget(
      auraColor: color,
      moodKey: moodKey,
      animated: active,
      intensity: active ? 0.95 : 0.55,
      borderRadius: BorderRadius.circular(size),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color.lerp(color, Colors.white, 0.25)!,
              Color.lerp(color, Colors.black, 0.35)!,
            ],
          ),
        ),
        child: Icon(
          mood?.icon ?? Icons.auto_awesome_rounded,
          size: size * 0.42,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}
