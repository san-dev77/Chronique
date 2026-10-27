import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';
import 'auth_login_screen.dart';

/// Ecran d'accueil, avant toute connexion.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _open(BuildContext context, {required bool signUp}) {
    // `push` et non `pushReplacement` : sans cela l'accueil se retirait de la
    // pile, et le retour depuis l'inscription laissait un ecran noir.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AuthLoginScreen(initialIsSignUp: signUp),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.skyBlue;

    return AuthShell(
      tagline: 'Vos souvenirs\nont une mémoire.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Marque : visible seulement quand le volet de gauche est absent.
          LayoutBuilder(builder: (context, _) {
            final narrow = MediaQuery.sizeOf(context).width < 940;
            if (!narrow) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent,
                          Color.lerp(accent, Colors.black, 0.25)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.36),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_stories_rounded,
                        color: Colors.white, size: 29),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Vos souvenirs\nont une mémoire.',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      height: 1.18,
                      letterSpacing: -0.8,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ],
              ),
            );
          }),

          Text(
            'Commencez',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Créez un compte pour retrouver vos chroniques sur tous vos '
            'appareils, ou connectez-vous si vous en avez déjà un.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.6,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 30),

          AuthPrimaryButton(
            label: 'Créer un compte',
            icon: Icons.person_add_rounded,
            onTap: () => _open(context, signUp: true),
          ),
          const SizedBox(height: 12),
          AuthGhostButton(
            label: 'J\'ai déjà un compte',
            icon: Icons.login_rounded,
            onTap: () => _open(context, signUp: false),
          ),

          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'ou',
                  style: TextStyle(
                    fontSize: 12.5,
                    color:
                        isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Utilisation sans compte : les notes restent sur l'appareil.
          Center(
            child: _PlainLink(
              label: 'Continuer sans compte',
              onTap: () => Navigator.pushReplacementNamed(context, '/main'),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Vos chroniques resteront sur cet appareil uniquement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: (isDark ? AppTheme.textMutedDark : AppTheme.textMuted)
                    .withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlainLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _PlainLink({required this.label, required this.onTap});

  @override
  State<_PlainLink> createState() => _PlainLinkState();
}

class _PlainLinkState extends State<_PlainLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.skyBlue;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: accent,
              decoration:
                  _hover ? TextDecoration.underline : TextDecoration.none,
              decorationColor: accent,
            ),
          ),
        ),
      ),
    );
  }
}
