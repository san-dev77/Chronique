import 'package:flutter/material.dart';
import '../widgets/note_logo.dart';
import '../widgets/primary_button.dart';
import 'auth_login_screen.dart';

/// Écran d'accueil minimaliste : Connexion ou Continuer sans compte
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
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
              Colors.white,
              Colors.grey.shade50,
              Colors.blue.shade50.withOpacity(0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Logo avec animation
                    Hero(
                      tag: 'app_logo',
                      child: const NoteLogo(size: 130),
                    ),

                    const SizedBox(height: 36),

                    // Titre
                    const Text(
                      'Chroniques',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      'The Chronique Box',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w300,
                        color: Color(0xFF4A4A4A),
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description avec meilleur contraste
                    Text(
                      'Capturez vos souvenirs,\nracontez votre chronique',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                        height: 1.6,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Features
                    _buildFeature(
                      Icons.cloud_sync_rounded,
                      'Synchronisation automatique',
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildFeature(
                      Icons.photo_library_rounded,
                      'Illustrez vos récits avec des images',
                      Colors.purple,
                    ),
                    const SizedBox(height: 12),
                    _buildFeature(
                      Icons.devices_rounded,
                      'Accessible sur tous vos appareils',
                      Colors.green,
                    ),

                    const Spacer(flex: 2),

                    // Bouton Connexion avec gradient
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AuthLoginScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 56,
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded,
                                    color: Colors.white, size: 24),
                                SizedBox(width: 12),
                                Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bouton Inscription
                    SecondaryButton(
                      text: 'Créer un compte',
                      icon: Icons.person_add_rounded,
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AuthLoginScreen(initialIsSignUp: true),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
    );
  }
}
