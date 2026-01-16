import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/note_logo.dart';

/// Splash Screen clean et cohérent avec l'app de notes
class SplashScreenClean extends StatefulWidget {
  const SplashScreenClean({super.key});

  @override
  State<SplashScreenClean> createState() => _SplashScreenCleanState();
}

class _SplashScreenCleanState extends State<SplashScreenClean>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _notesController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  final List<NoteCard> _floatingNotes = [];

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _notesController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Créer des notes flottantes
    _initFloatingNotes();

    _startAnimations();
  }

  void _initFloatingNotes() {
    final colors = [
      Colors.amber.shade100,
      Colors.blue.shade100,
      Colors.pink.shade100,
      Colors.green.shade100,
      Colors.purple.shade100,
    ];

    final random = math.Random();

    for (int i = 0; i < 5; i++) {
      _floatingNotes.add(NoteCard(
        color: colors[i],
        delay: i * 0.15,
        startX: -0.3 + (i * 0.15),
        endX: 0.1 + (i * 0.12),
        rotation: (random.nextDouble() - 0.5) * 0.3,
      ));
    }
  }

  void _startAnimations() async {
    _controller.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _notesController.forward();

    await Future.delayed(const Duration(milliseconds: 2500));

    if (mounted) {
      if (AuthService.instance.isSignedIn) {
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        Navigator.of(context).pushReplacementNamed('/welcome');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Stack(
        children: [
          // Notes flottantes en arrière-plan
          ...List.generate(_floatingNotes.length, (index) {
            final note = _floatingNotes[index];
            return AnimatedBuilder(
              animation: _notesController,
              builder: (context, child) {
                final progress =
                    (_notesController.value - note.delay).clamp(0.0, 1.0);
                final curve = Curves.easeOutCubic.transform(progress);

                return Positioned(
                  left: size.width *
                      (note.startX + (note.endX - note.startX) * curve),
                  top: size.height * (0.15 + index * 0.12),
                  child: Transform.rotate(
                    angle: note.rotation * curve,
                    child: Opacity(
                      opacity: (curve * 0.6).clamp(0.0, 0.6),
                      child: Container(
                        width: 120,
                        height: 140,
                        decoration: BoxDecoration(
                          color: note.color,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 60,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 80,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 90,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Contenu principal
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      const NoteLogo(size: 140, isRound: true),

                      const SizedBox(height: 40),

                      // Titre
                      const Text(
                        'Chroniques',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C3E50),
                          letterSpacing: -0.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Sous-titre
                      Text(
                        'The Chronique Box',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Loader simple et élégant
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.amber.shade400,
                          ),
                          backgroundColor: Colors.grey.shade200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoteCard {
  final Color color;
  final double delay;
  final double startX;
  final double endX;
  final double rotation;

  NoteCard({
    required this.color,
    required this.delay,
    required this.startX,
    required this.endX,
    required this.rotation,
  });
}
