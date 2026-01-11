import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_logo.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _pulseController;

  late Animation<double> _logoAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  // Couleurs définies directement pour éviter les erreurs
  static const Color primaryColor = Color(0xFF4F6F8F);
  static const Color secondaryColor = Color(0xFF7B9EA8);

  @override
  void initState() {
    super.initState();

    // Configuration de la status bar
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    // Contrôleur pour l'animation du logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Contrôleur pour l'animation de fade
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Contrôleur pour l'animation de scale
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Contrôleur pour l'animation de pulse
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Animation du logo (rotation + scale)
    _logoAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    // Animation de fade
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    // Animation de scale
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    ));

    // Animation de pulse
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Séquence d'animations
    _startAnimations();
  }

  void _startAnimations() async {
    // Démarrer l'animation du logo
    await _logoController.forward();

    // Démarrer l'animation de fade
    _fadeController.forward();

    // Démarrer l'animation de scale
    _scaleController.forward();

    // Démarrer l'animation de pulse en boucle
    _pulseController.repeat(reverse: true);

    // Attendre et naviguer
    await Future.delayed(const Duration(milliseconds: 3000));

    if (mounted) {
      // Vérifier si l'utilisateur est connecté
      final isSignedIn = AuthService.instance.isSignedIn;

      if (isSignedIn) {
        // Utilisateur connecté → écran principal
        Navigator.of(context).pushReplacementNamed('/main');
      } else {
        // Pas connecté → écran d'authentification
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo principal avec animations
                AnimatedBuilder(
                  animation: _logoAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoAnimation.value,
                      child: Transform.rotate(
                        angle: _logoAnimation.value * 0.1,
                        child: Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                                spreadRadius: 5,
                              ),
                              BoxShadow(
                                color: primaryColor.withOpacity(0.1),
                                blurRadius: 40,
                                offset: const Offset(0, 20),
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: const AppLogo(
                                  size: 120,
                                  showBorder: false,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 60),

                // Titre de l'application
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _fadeController,
                          curve: Curves.easeOutCubic,
                        )),
                        child: Column(
                          children: [
                            Text(
                              'Note Box',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: primaryColor,
                                letterSpacing: 2.0,
                                shadows: [
                                  Shadow(
                                    color: primaryColor.withOpacity(0.3),
                                    offset: const Offset(0, 4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Vos idées, organisées',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 80),

                // Indicateur de chargement stylé
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 3,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 40),

                // Texte de chargement
                AnimatedBuilder(
                  animation: _fadeAnimation,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        'Chargement...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
