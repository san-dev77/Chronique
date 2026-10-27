import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/accent_color_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Ecran d'ouverture : la boite qui s'ouvre.
///
/// Un volume ferme se pose, son couvercle bascule puis s'envole, un faisceau
/// s'echappe de l'ouverture et la marque s'eleve de l'interieur — masquee par
/// la face avant tant qu'elle n'a pas franchi le bord. C'est cette occultation
/// qui donne le sentiment qu'elle sort du volume au lieu d'apparaitre devant.
///
/// L'ancienne version durait 2,8 s, faisait glisser cinq fiches pastel sans
/// rapport avec l'app et forcait un fond gris clair meme en theme sombre.
class SplashScreenClean extends StatefulWidget {
  const SplashScreenClean({super.key});

  @override
  State<SplashScreenClean> createState() => _SplashScreenCleanState();
}

class _SplashScreenCleanState extends State<SplashScreenClean>
    with SingleTickerProviderStateMixin {
  /// Duree totale, fondu de sortie compris.
  static const int _totalMs = 1750;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _totalMs),
  );

  late final List<_Mote> _motes = _buildMotes();
  bool _leaving = false;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _leave();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Reglage systeme « reduire les animations » : on montre l'image finale
      // un court instant plutot que de jouer la sequence.
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.value = 0.78;
        Future.delayed(const Duration(milliseconds: 550), _leave);
      } else {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Un ecran d'ouverture se subit : il doit pouvoir etre abrege.
  void _skip() {
    if (_leaving) return;
    _leave();
  }

  void _leave() {
    if (_leaving || !mounted) return;
    _leaving = true;
    Navigator.of(context).pushReplacementNamed(
      AuthService.instance.isSignedIn ? '/main' : '/welcome',
    );
  }

  List<_Mote> _buildMotes() {
    // Graine fixe : l'ouverture est identique a chaque lancement.
    final rnd = math.Random(90210);
    return List.generate(26, (_) {
      return _Mote(
        x: (rnd.nextDouble() - 0.5) * 1.7,
        delay: rnd.nextDouble() * 0.55,
        speed: 0.75 + rnd.nextDouble() * 0.9,
        size: 0.9 + rnd.nextDouble() * 2.2,
        drift: (rnd.nextDouble() - 0.5) * 34,
        phase: rnd.nextDouble() * 6.28,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Le fond suit le theme au lieu d'imposer un gris clair.
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: GestureDetector(
        onTap: _skip,
        behavior: HitTestBehavior.opaque,
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent) {
              _skip();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: ListenableBuilder(
            listenable: AccentColorService.instance,
            builder: (context, _) {
              final accent = AccentColorService.instance.accentColor;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _BoxSplashPainter(
                      ms: _controller.value * _totalMs,
                      accent: accent,
                      isDark: isDark,
                      motes: _motes,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Mote {
  final double x, delay, speed, size, drift, phase;
  const _Mote({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.drift,
    required this.phase,
  });
}

class _BoxSplashPainter extends CustomPainter {
  final double ms;
  final Color accent;
  final bool isDark;
  final List<_Mote> motes;

  _BoxSplashPainter({
    required this.ms,
    required this.accent,
    required this.isDark,
    required this.motes,
  });

  // ------------------------------------------------------------- utilitaires

  static double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

  /// Avancement d'un segment de la chronologie, entre deux instants.
  double _seg(double a, double b) => _clamp01((ms - a) / (b - a));

  /// Deceleration : la valeur arrive vite puis se pose.
  double _ease(double t, [double power = 3]) =>
      1 - math.pow(1 - _clamp01(t), power).toDouble();

  Color _a(Color c, double alpha) => c.withValues(alpha: _clamp01(alpha));

  Color get _ink => isDark ? AppTheme.textLight : AppTheme.textDark;
  Color get _muted => isDark ? AppTheme.textMutedDark : AppTheme.textMuted;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // La boite garde une taille lisible quel que soit l'ecran : elle grandit
    // un peu sur desktop, sans jamais suivre la fenetre.
    final scale =
        (math.min(size.width, size.height) / 640).clamp(0.85, 1.55).toDouble();

    final cx = size.width / 2;
    final baseY = size.height * 0.50;

    final arrive = _ease(_seg(0, 320));
    final settle = _ease(_seg(180, 520), 4);
    final open = _ease(_seg(300, 780));
    final spill = _ease(_seg(480, 1000), 2);
    final rise = _ease(_seg(620, 1180));
    final fly = _ease(_seg(880, 1320), 2);
    final sink = _ease(_seg(1000, 1380), 2);
    final nameA = _ease(_seg(1050, 1330), 2);
    final subA = _ease(_seg(1180, 1450), 2);
    final lift = _ease(_seg(1080, 1520));
    final out = _seg(1520, 1750);

    final bw = 128 * scale;
    final bh = 76 * scale;
    final dx = 20 * scale;
    final dy = 15 * scale;

    final drop =
        (1 - arrive) * 46 * scale - math.sin(settle * math.pi) * 5 * scale;
    final y0 = baseY + drop - lift * 26 * scale;

    final l = cx - bw / 2;
    final r = cx + bw / 2;
    final alpha = (1 - sink) * arrive;
    final mouthX = cx + dx / 2;

    _paintShadow(canvas, cx, y0, bw, bh, dx, alpha, open, scale);
    if (open > 0.02) _paintInterior(canvas, l, r, y0, dx, dy, alpha, spill);
    if (spill > 0.02) _paintBeam(canvas, size, mouthX, y0 - dy, bw, spill, scale);
    if (spill > 0.05) _paintMotes(canvas, mouthX, y0 - dy, bw, spill, sink, scale);

    // La marque est peinte AVANT les faces : c'est ce qui la fait sortir de la
    // boite au lieu de flotter devant.
    final markY = y0 - dy + 26 * scale - rise * 126 * scale;
    _paintMark(
      canvas,
      Offset(mouthX, markY - lift * 6 * scale),
      (46 + rise * 54) * scale,
      rise,
      math.min(1, rise * 1.25),
    );

    if (alpha > 0.01) {
      _paintFaces(canvas, l, r, y0, bw, bh, dx, dy, alpha, spill);
      _paintLid(canvas, mouthX, y0 - dy, bw, dx, dy, alpha, open, fly, scale);
    }

    _paintWordmark(canvas, size, nameA, subA, (1 - nameA) * 16 - lift * 4, scale);

    if (out > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = _a(isDark ? Colors.black : Colors.white, out),
      );
    }
  }

  // ---------------------------------------------------------------- couches

  void _paintShadow(Canvas canvas, double cx, double y0, double bw, double bh,
      double dx, double alpha, double open, double scale) {
    if (alpha <= 0.01) return;
    final center = Offset(cx + dx / 2, y0 + bh + 14 * scale);
    final radius = bw * (0.66 + open * 0.2);
    final paint = Paint()
      ..shader = ui.Gradient.radial(center, radius, [
        _a(isDark ? Colors.black : const Color(0xFF1E3A5F),
            (isDark ? 0.85 : 0.55) * alpha * (isDark ? 0.5 : 0.22) * 2),
        _a(Colors.black, 0),
      ]);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1, 15 * scale / (bw * 0.62));
    canvas.drawCircle(Offset.zero, bw * 0.62, paint);
    canvas.restore();
  }

  void _paintInterior(Canvas canvas, double l, double r, double y0, double dx,
      double dy, double alpha, double spill) {
    final path = Path()
      ..moveTo(l, y0)
      ..lineTo(l + dx, y0 - dy)
      ..lineTo(r + dx, y0 - dy)
      ..lineTo(r, y0)
      ..close();
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y0 - dy),
        Offset(0, y0 + 10),
        [
          _a(accent, (0.30 + 0.55 * spill) * alpha),
          isDark
              ? _a(const Color(0xFF0A1520), alpha)
              : _a(const Color(0xFF9FB8D0), alpha),
        ],
      );
    canvas.drawPath(path, paint);
  }

  /// Cone de lumiere qui s'echappe de l'ouverture.
  void _paintBeam(Canvas canvas, Size size, double mouthX, double mouthY,
      double bw, double spill, double scale) {
    final beamH = 210 * spill * scale;
    final topW = bw * (0.34 + 0.5 * spill);
    // En theme clair, un halo blanc se perdrait : on l'assombrit et on le
    // sature pour qu'il reste lisible sur fond clair.
    final peak = isDark ? 0.42 : 0.34;

    final beam = Path()
      ..moveTo(mouthX - bw * 0.30, mouthY)
      ..lineTo(mouthX + bw * 0.30, mouthY)
      ..lineTo(mouthX + topW, mouthY - beamH)
      ..lineTo(mouthX - topW, mouthY - beamH)
      ..close();

    canvas.drawPath(
      beam,
      Paint()
        ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver
        ..shader = ui.Gradient.linear(
          Offset(0, mouthY),
          Offset(0, mouthY - beamH),
          [_a(accent, peak * spill), _a(accent, 0)],
        ),
    );

    final glowR = 96 * spill * scale;
    if (glowR > 1) {
      canvas.drawCircle(
        Offset(mouthX, mouthY),
        glowR,
        Paint()
          ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver
          ..shader = ui.Gradient.radial(Offset(mouthX, mouthY), glowR, [
            _a(accent, (isDark ? 0.55 : 0.40) * spill),
            _a(accent, 0),
          ]),
      );
    }
  }

  void _paintMotes(Canvas canvas, double mouthX, double mouthY, double bw,
      double spill, double sink, double scale) {
    for (final m in motes) {
      final t = _clamp01((spill - m.delay) / (1 - m.delay)) * m.speed;
      if (t <= 0) continue;
      final climb = math.min(t, 1.0);
      final my = mouthY - climb * 168 * scale;
      final mx = mouthX +
          m.x * bw * 0.30 +
          math.sin(climb * 3.1 + m.phase) * m.drift * climb * scale;
      final fade = math.sin(climb * math.pi) * (1 - sink);
      if (fade < 0.03) continue;

      canvas.drawCircle(Offset(mx, my), m.size * scale,
          Paint()..color = _a(accent, fade * 0.9));
      if (fade > 0.45) {
        canvas.drawCircle(
          Offset(mx, my),
          m.size * 0.45 * scale,
          Paint()..color = _a(Colors.white, (fade - 0.45) * 1.2),
        );
      }
    }
  }

  /// La marque : un livre ouvert, trace depuis la reliure vers l'exterieur.
  void _paintMark(
      Canvas canvas, Offset c, double size, double alpha, double progress) {
    if (alpha <= 0.01) return;
    final p = _clamp01(progress);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(size / 100);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _a(_ink, alpha);

    canvas.drawLine(Offset(0, -34 * p), Offset(0, 34 * p), paint);

    for (final dir in const [-1.0, 1.0]) {
      final leaf = Path()
        ..moveTo(0, -32)
        ..quadraticBezierTo(dir * 26 * p, -40 * p, dir * 44 * p, -26 * p)
        ..lineTo(dir * 44 * p, 30 * p)
        ..quadraticBezierTo(dir * 26 * p, 20 * p, 0, 32);
      canvas.drawPath(leaf, paint);
    }
    canvas.restore();
  }

  void _paintFaces(Canvas canvas, double l, double r, double y0, double bw,
      double bh, double dx, double dy, double alpha, double spill) {
    // face droite, fuyante
    final side = Path()
      ..moveTo(r, y0)
      ..lineTo(r + dx, y0 - dy)
      ..lineTo(r + dx, y0 + bh - dy)
      ..lineTo(r, y0 + bh)
      ..close();
    canvas.drawPath(
      side,
      Paint()
        ..color = _a(
            isDark ? const Color(0xFF16304F) : const Color(0xFFB9CCE0), alpha),
    );

    // face avant
    final front = RRect.fromRectAndRadius(
      Rect.fromLTWH(l, y0, bw, bh),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      front,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, y0),
          Offset(0, y0 + bh),
          isDark
              ? [_a(const Color(0xFF24456E), alpha), _a(const Color(0xFF152944), alpha)]
              : [_a(const Color(0xFFE2ECF6), alpha), _a(const Color(0xFFC7D8E9), alpha)],
        ),
    );

    // arete lumineuse sur le bord de l'ouverture
    final edge = Path()
      ..moveTo(l, y0)
      ..lineTo(r, y0)
      ..lineTo(r + dx, y0 - dy);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _a(accent, (0.45 + 0.45 * spill) * alpha),
    );
  }

  void _paintLid(Canvas canvas, double mouthX, double mouthY, double bw,
      double dx, double dy, double alpha, double open, double fly, double scale) {
    final a = alpha * (1 - fly * 0.92);
    if (a <= 0.01) return;

    canvas.save();
    canvas.translate(
      mouthX + fly * 46 * scale,
      mouthY - open * 20 * scale - fly * 120 * scale,
    );
    canvas.rotate(-open * 0.42 - fly * 0.9);
    canvas.scale(1, 1 - open * 0.42);

    final lid = Path()
      ..moveTo(-bw / 2 - 5 * scale, 0)
      ..lineTo(-bw / 2 - 5 * scale + dx, -dy)
      ..lineTo(bw / 2 + 5 * scale + dx, -dy)
      ..lineTo(bw / 2 + 5 * scale, 0)
      ..close();

    canvas.drawPath(
      lid,
      Paint()
        ..color = _a(
            isDark ? const Color(0xFF2B5382) : const Color(0xFFCFDFEE), a),
    );
    canvas.drawPath(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _a(accent, 0.6 * a),
    );
    canvas.restore();
  }

  void _paintWordmark(Canvas canvas, Size size, double nameA, double subA,
      double rise, double scale) {
    final y = size.height * 0.70 + rise * scale;

    if (nameA > 0.01) {
      _text(
        canvas,
        'Chroniques',
        Offset(size.width / 2, y),
        TextStyle(
          fontSize: 30 * scale,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: _a(_ink, nameA),
        ),
      );
    }

    if (subA > 0.01) {
      _text(
        canvas,
        'THE STORY BOX',
        Offset(size.width / 2, y + 30 * scale),
        TextStyle(
          fontSize: 12 * scale,
          fontWeight: FontWeight.w500,
          letterSpacing: 3,
          color: _a(_muted, subA),
        ),
      );
    }
  }

  void _text(Canvas canvas, String value, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  bool shouldRepaint(_BoxSplashPainter old) =>
      old.ms != ms || old.accent != accent || old.isDark != isDark;
}
