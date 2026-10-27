import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Cadre commun aux ecrans d'accueil, de connexion et d'inscription.
///
/// Sur desktop, un formulaire de 440 px centre au milieu d'une page blanche de
/// 1 900 px flotte dans le vide. Ces ecrans adoptent donc une mise en page en
/// deux volets : a gauche l'identite de l'app, a droite ce qu'on vient y
/// faire. Sur telephone, seul le volet de droite subsiste.
class AuthShell extends StatelessWidget {
  /// Contenu utile : formulaire ou boutons d'accueil.
  final Widget child;

  /// Bouton de retour, si l'ecran est empile.
  final Widget? leading;

  /// Phrase affichee sous la marque, dans le volet de gauche.
  final String tagline;

  const AuthShell({
    super.key,
    required this.child,
    this.tagline = 'Capturez vos souvenirs, racontez votre chronique.',
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.skyBlue;
    final surface = isDark ? AppTheme.bgDark : Colors.white;

    return Scaffold(
      backgroundColor: surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final twoPane = constraints.maxWidth >= 940;

          final form = SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                    child: leading!,
                  ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: twoPane ? 56 : 28,
                        vertical: 28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: child,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (!twoPane) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(surface, accent, isDark ? 0.10 : 0.05)!,
                    surface,
                  ],
                ),
              ),
              child: form,
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 5,
                child: _BrandPanel(accent: accent, tagline: tagline),
              ),
              Expanded(flex: 4, child: form),
            ],
          );
        },
      ),
    );
  }
}

/// Volet de gauche : la marque, sa promesse, et ce que l'app sait faire.
class _BrandPanel extends StatelessWidget {
  final Color accent;
  final String tagline;

  const _BrandPanel({required this.accent, required this.tagline});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppTheme.bgDark, accent, 0.22)!,
            AppTheme.bgDark,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Halo diffus, echo des auras de l'app.
          Positioned(
            left: -120,
            top: -80,
            child: Container(
              width: 460,
              height: 460,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.30),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: -140,
            bottom: -110,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: 0.18),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 52, 48, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent,
                              Color.lerp(accent, Colors.black, 0.25)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.4),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_stories_rounded,
                            color: Colors.white, size: 23),
                      ),
                      const SizedBox(width: 13),
                      const Text(
                        'Chroniques',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  Text(
                    tagline,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.9,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Un journal qui garde vos images, vos mots et l’humeur '
                    'du moment — et vous les rend quand vous les aviez oubliés.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.65,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),

                  const Spacer(),

                  const _Feature(
                    icon: Icons.cloud_sync_rounded,
                    text: 'Synchronisation automatique',
                  ),
                  const SizedBox(height: 16),
                  const _Feature(
                    icon: Icons.photo_library_rounded,
                    text: 'Illustrez vos récits avec vos photos',
                  ),
                  const SizedBox(height: 16),
                  const _Feature(
                    icon: Icons.devices_rounded,
                    text: 'Sur votre ordinateur comme sur votre téléphone',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Feature({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 17, color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton principal des ecrans d'authentification.
class AuthPrimaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool busy;
  final VoidCallback onTap;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
  });

  @override
  State<AuthPrimaryButton> createState() => _AuthPrimaryButtonState();
}

class _AuthPrimaryButtonState extends State<AuthPrimaryButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.skyBlue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 110),
          scale: _down ? 0.975 : 1,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [accent, Color.lerp(accent, Colors.black, 0.22)!],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _hover ? 0.45 : 0.26),
                  blurRadius: _hover ? 22 : 12,
                  offset: Offset(0, _hover ? 8 : 4),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire, contour seul.
class AuthGhostButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  const AuthGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  @override
  State<AuthGhostButton> createState() => _AuthGhostButtonState();
}

class _AuthGhostButtonState extends State<AuthGhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.skyBlue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _hover
                ? accent.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hover
                  ? accent
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.12)),
              width: 1.4,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon,
                      size: 19,
                      color: _hover
                          ? accent
                          : (isDark ? Colors.white70 : AppTheme.textDark)),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _hover
                        ? accent
                        : (isDark ? Colors.white : AppTheme.textDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Fleche de retour des ecrans d'authentification.
class AuthBackButton extends StatefulWidget {
  final VoidCallback onTap;

  const AuthBackButton({super.key, required this.onTap});

  @override
  State<AuthBackButton> createState() => _AuthBackButtonState();
}

class _AuthBackButtonState extends State<AuthBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.skyBlue;

    return Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Retour',
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _hover
                    ? accent.withValues(alpha: 0.13)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: _hover
                    ? accent
                    : (isDark ? Colors.white70 : AppTheme.textDark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
