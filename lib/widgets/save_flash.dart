import 'dart:math';
import 'package:flutter/material.dart';

/// Confirmation visuelle d'un enregistrement.
///
/// S'affiche par-dessus l'ecran, se joue toute seule et se retire. Rien a
/// gerer chez l'appelant : `await showSaveFlash(context)` puis on continue.
Future<void> showSaveFlash(
  BuildContext context, {
  Color color = const Color(0xFF3E9E74),
  String message = 'Enregistré',
}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final entry = OverlayEntry(
    builder: (_) => _SaveFlash(color: color, message: message),
  );
  overlay.insert(entry);

  await Future<void>.delayed(const Duration(milliseconds: 620));
  entry.remove();
}

class _SaveFlash extends StatefulWidget {
  final Color color;
  final String message;

  const _SaveFlash({required this.color, required this.message});

  @override
  State<_SaveFlash> createState() => _SaveFlashState();
}

class _SaveFlashState extends State<_SaveFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            // Apparition franche, disparition douce.
            final appear = Curves.easeOutBack.transform((t / 0.42).clamp(0.0, 1.0));
            final fade = t < 0.62 ? 1.0 : 1 - ((t - 0.62) / 0.38).clamp(0.0, 1.0);

            return Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: 0.86 + 0.14 * appear,
                child: CustomPaint(
                  painter: _RipplePainter(progress: t, color: widget.color),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 22),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.45),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CustomPaint(
                            painter: _CheckPainter(
                              progress:
                                  ((t - 0.14) / 0.38).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Onde qui s'echappe de la pastille.
class _RipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RipplePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 2; i++) {
      final delay = i * 0.16;
      final t = ((progress - delay) / 0.6).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        center,
        size.longestSide * (0.5 + 0.55 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1 - eased) + 0.3
          ..color = color.withValues(alpha: (1 - eased) * 0.4),
      );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.progress != progress;
}

/// Coche qui se trace, plutot que d'apparaitre d'un bloc.
class _CheckPainter extends CustomPainter {
  final double progress;

  const _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;

    final a = Offset(size.width * 0.22, size.height * 0.52);
    final b = Offset(size.width * 0.43, size.height * 0.72);
    final c = Offset(size.width * 0.78, size.height * 0.30);

    final firstLength = (b - a).distance;
    final secondLength = (c - b).distance;
    final total = firstLength + secondLength;
    final drawn = total * Curves.easeOutCubic.transform(progress);

    final path = Path()..moveTo(a.dx, a.dy);
    if (drawn <= firstLength) {
      final p = Offset.lerp(a, b, drawn / max(firstLength, 0.001))!;
      path.lineTo(p.dx, p.dy);
    } else {
      path.lineTo(b.dx, b.dy);
      final p = Offset.lerp(
          b, c, ((drawn - firstLength) / max(secondLength, 0.001)).clamp(0.0, 1.0))!;
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Confirmation d'une suppression : la coche cede la place a une corbeille
/// qui se referme, et l'onde rentre au lieu de s'ouvrir.
Future<void> showDeleteFlash(
  BuildContext context, {
  String message = 'Supprimé',
}) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  final entry = OverlayEntry(
    builder: (_) => const _DeleteFlash(),
  );
  overlay.insert(entry);

  await Future<void>.delayed(const Duration(milliseconds: 620));
  entry.remove();
}

class _DeleteFlash extends StatefulWidget {
  const _DeleteFlash();

  @override
  State<_DeleteFlash> createState() => _DeleteFlashState();
}

class _DeleteFlashState extends State<_DeleteFlash>
    with SingleTickerProviderStateMixin {
  static const _color = Color(0xFFD1544B);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final appear =
                Curves.easeOutBack.transform((t / 0.4).clamp(0.0, 1.0));
            final fade =
                t < 0.6 ? 1.0 : 1 - ((t - 0.6) / 0.4).clamp(0.0, 1.0);
            // La pastille se retracte legerement : le geste « avale » la note.
            final shrink = 1 - Curves.easeIn.transform(
                    ((t - 0.55) / 0.45).clamp(0.0, 1.0)) *
                0.18;

            return Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: (0.86 + 0.14 * appear) * shrink,
                child: CustomPaint(
                  painter: _ImplodePainter(progress: t, color: _color),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 22),
                    decoration: BoxDecoration(
                      color: _color,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _color.withValues(alpha: 0.45),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.rotate(
                          angle: (1 - appear) * 0.5,
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white, size: 42),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Supprimé',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Anneaux qui convergent vers le centre, a l'inverse de l'enregistrement.
class _ImplodePainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ImplodePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 2; i++) {
      final delay = i * 0.14;
      final t = ((progress - delay) / 0.55).clamp(0.0, 1.0);
      if (t <= 0 || t >= 1) continue;
      final eased = Curves.easeOutCubic.transform(t);
      canvas.drawCircle(
        center,
        size.longestSide * (1.05 - 0.5 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * eased + 0.3
          ..color = color.withValues(alpha: (1 - eased) * 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_ImplodePainter old) => old.progress != progress;
}
