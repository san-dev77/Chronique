import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';

/// Splash Screen MASTERCLASS avec effets 3D et particules animées
class SplashScreenMasterclass extends StatefulWidget {
  const SplashScreenMasterclass({super.key});

  @override
  State<SplashScreenMasterclass> createState() =>
      _SplashScreenMasterclassState();
}

class _SplashScreenMasterclassState extends State<SplashScreenMasterclass>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _rotationController;
  late AnimationController _particlesController;
  late AnimationController _glowController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;

  final List<Particle> _particles = [];
  final int _particleCount = 50;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Contrôleur principal
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Contrôleur rotation 3D
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Contrôleur particules
    _particlesController = AnimationController(
      duration: const Duration(milliseconds: 5000),
      vsync: this,
    );

    // Contrôleur glow pulsant
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: Curves.elasticOut,
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );

    // Initialiser particules
    _initParticles();

    // Démarrer animations
    _startAnimations();
  }

  void _initParticles() {
    final random = math.Random();
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 4 + 2,
        speedX: (random.nextDouble() - 0.5) * 0.002,
        speedY: (random.nextDouble() - 0.5) * 0.002,
        opacity: random.nextDouble() * 0.5 + 0.3,
      ));
    }
  }

  void _startAnimations() async {
    // Animation principale
    _mainController.forward();

    // Rotation 3D continue
    _rotationController.repeat();

    // Glow pulsant
    _glowController.repeat(reverse: true);

    // Particules
    _particlesController.repeat();
    _particlesController.addListener(_updateParticles);

    // Attendre puis naviguer
    await Future.delayed(const Duration(milliseconds: 4000));

    if (mounted) {
      final isSignedIn = AuthService.instance.isSignedIn;

      if (isSignedIn) {
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  void _updateParticles() {
    setState(() {
      for (var particle in _particles) {
        particle.update();
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rotationController.dispose();
    _particlesController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F2027),
              const Color(0xFF203A43),
              const Color(0xFF2C5364),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Particules en arrière-plan
            CustomPaint(
              size: size,
              painter: ParticlesPainter(_particles),
            ),

            // Contenu principal
            Center(
              child: AnimatedBuilder(
                animation: _mainController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo 3D rotatif avec glow
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _rotationController,
                              _glowController,
                            ]),
                            builder: (context, child) {
                              return Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.001)
                                  ..rotateY(_rotationAnimation.value)
                                  ..rotateX(_rotationAnimation.value * 0.5),
                                child: Container(
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.blue.shade400,
                                        Colors.purple.shade600,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(
                                            0.5 * _glowAnimation.value),
                                        blurRadius: 40 * _glowAnimation.value,
                                        spreadRadius: 10 * _glowAnimation.value,
                                      ),
                                      BoxShadow(
                                        color: Colors.purple.withOpacity(
                                            0.3 * _glowAnimation.value),
                                        blurRadius: 60 * _glowAnimation.value,
                                        spreadRadius: 15 * _glowAnimation.value,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.note_alt_rounded,
                                    size: 80,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 40),

                          // Titre avec effet de glitch
                          ShaderMask(
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: [
                                  Colors.cyan.shade300,
                                  Colors.blue.shade400,
                                  Colors.purple.shade400,
                                ],
                              ).createShader(bounds);
                            },
                            child: const Text(
                              'Note Box',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.cyan,
                                    offset: Offset(2, 2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Sous-titre avec effet néon
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.cyan.withOpacity(0.5),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyan.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Text(
                              'Vos idées, synchronisées',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ),

                          const SizedBox(height: 60),

                          // Loader futuriste
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Cercle extérieur rotatif
                                AnimatedBuilder(
                                  animation: _rotationController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _rotationAnimation.value,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            width: 3,
                                            color: Colors.transparent,
                                          ),
                                          gradient: SweepGradient(
                                            colors: [
                                              Colors.cyan.shade400,
                                              Colors.blue.shade600,
                                              Colors.purple.shade600,
                                              Colors.cyan.shade400,
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                // Cercle intérieur
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF0F2027),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.cyan.withOpacity(0.3),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                // Points clignotants
                                AnimatedBuilder(
                                  animation: _glowController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.cyan.withOpacity(
                                                _glowAnimation.value),
                                            blurRadius:
                                                20 * _glowAnimation.value,
                                            spreadRadius:
                                                4 * _glowAnimation.value,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Texte de chargement avec effet machine à écrire
                          AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              return Text(
                                'Initialisation${('.' * ((_mainController.value * 3).toInt() + 1)).substring(0, ((_mainController.value * 3).toInt() % 4))}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.cyan.shade200,
                                  letterSpacing: 2,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Version en bas avec effet néon
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'v1.0.0 • BETA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.cyan.shade300,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Classe Particule pour l'effet d'arrière-plan
class Particle {
  double x;
  double y;
  double size;
  double speedX;
  double speedY;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.opacity,
  });

  void update() {
    x += speedX;
    y += speedY;

    // Rebond sur les bords
    if (x < 0 || x > 1) speedX *= -1;
    if (y < 0 || y > 1) speedY *= -1;

    // Garder dans les limites
    x = x.clamp(0.0, 1.0);
    y = y.clamp(0.0, 1.0);
  }
}

/// Painter pour dessiner les particules
class ParticlesPainter extends CustomPainter {
  final List<Particle> particles;

  ParticlesPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = Colors.cyan.withOpacity(particle.opacity * 0.6)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      final offset = Offset(
        particle.x * size.width,
        particle.y * size.height,
      );

      canvas.drawCircle(offset, particle.size, paint);

      // Ajouter un glow
      final glowPaint = Paint()
        ..color = Colors.blue.withOpacity(particle.opacity * 0.3)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(offset, particle.size * 2, glowPaint);
    }

    // Dessiner des lignes entre particules proches
    for (int i = 0; i < particles.length; i++) {
      for (int j = i + 1; j < particles.length; j++) {
        final p1 = particles[i];
        final p2 = particles[j];

        final dx = p1.x - p2.x;
        final dy = p1.y - p2.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        if (distance < 0.15) {
          final linePaint = Paint()
            ..color = Colors.cyan.withOpacity((1 - distance / 0.15) * 0.2)
            ..strokeWidth = 1;

          canvas.drawLine(
            Offset(p1.x * size.width, p1.y * size.height),
            Offset(p2.x * size.width, p2.y * size.height),
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
