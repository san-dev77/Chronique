import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_chrome.dart';

/// En-tete commun aux ecrans secondaires.
///
/// Les ecrans avaient chacun leur propre bandeau, cale pour un telephone :
/// pave de couleur pleine largeur, titre de 28 px, icone dans un carre
/// lumineux. Etire sur un ecran de 1900 px, l'ensemble tenait mal. Celui-ci
/// suit la meme grammaire que l'ecran Chroniques : une barre basse, bornee et
/// centree, epinglee pendant le defilement sur desktop.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? accent;
  final List<Widget> actions;
  final Widget? bottom;
  final double width;

  /// Affiche une fleche de retour. Necessaire quand l'ecran est empile plutot
  /// qu'affiche comme onglet.
  final VoidCallback? onBack;

  const ScreenHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.width,
    this.subtitle,
    this.accent,
    this.actions = const [],
    this.bottom,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = accent ?? AppTheme.skyBlue;
    final insets = Responsive.contentInsets(width);
    final wide = Responsive.useSidebar(width);

      // Hauteur fixe + texte : l'echelle de police du systeme peut faire
      // deborder. On la borne ici, sans toucher aux surfaces de lecture ou
      // elle compte vraiment (note ouverte, editeur).
    final surface = isDark ? AppTheme.surfaceDark : Colors.white;

    // Les icones de la barre d'etat suivent la surface de l'en-tete. Sans
    // cela, elles restaient claires — reglees pour le bandeau bleu de
    // l'ecran Chroniques — et devenaient invisibles sur un en-tete blanc.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Stack(
        children: [
          Container(
      padding: EdgeInsets.fromLTRB(
        insets.left,
        wide ? 22 : 16,
        insets.right,
        bottom == null ? 18 : 14,
      ),
      // Meme grammaire que la barre laterale : la teinte de l'ecran affleure
      // en haut puis s'efface, au lieu d'un aplat ferme par une arete.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, 0.55, 1],
          colors: [
            Color.lerp(surface, tint, isDark ? 0.07 : 0.032)!,
            surface,
            surface,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (onBack != null) ...[
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Retour',
                  color: isDark ? Colors.white70 : AppTheme.textMuted,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(tint, Colors.white, 0.18)!,
                      Color.lerp(tint, Colors.black, 0.26)!,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                // Un reflet en haut : sans lui le degrade reste plat et la
                // plaque ressemble a un carre de couleur.
                child: Stack(
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.26),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Center(child: Icon(icon, color: Colors.white, size: 21)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: wide ? 25 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppTheme.textMutedDark
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ...actions,
            ],
          ),
          if (bottom != null) ...[
            const SizedBox(height: 16),
            bottom!,
          ],
        ],
      ),
          ),
          Positioned(
            left: insets.left,
            right: insets.right,
            bottom: 0,
            child: FadingDivider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.09)
                  : tint.withValues(alpha: 0.16),
              fade: 0.06,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// En-tete de hauteur fixe qui reste en place pendant le defilement.
class PinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  const PinnedHeaderDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Le relief n'apparait que lorsque le contenu glisse sous l'en-tete.
    // Une ombre permanente serait du decor ; celle-ci dit ou l'on en est.
    return SizedBox.expand(
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          boxShadow: overlaps
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.34)
                        : AppTheme.skyBlue.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(PinnedHeaderDelegate old) => true;
}

/// Place l'en-tete dans un sliver : renvoie le sliver d'en-tete adapte a la largeur.
Widget screenHeaderSliver({
  required double width,
  required Widget header,
  double pinnedHeight = 96,
}) {
  if (Responsive.useSidebar(width)) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: PinnedHeaderDelegate(height: pinnedHeight, child: header),
    );
  }
  return SliverToBoxAdapter(child: header);
}

/// Bouton de rafraichissement des en-tetes.
///
/// Sur desktop, le « tirer pour rafraichir » n'existe pas : il faut un bouton.
class RefreshAction extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final String tooltip;
  final Color? accent;

  const RefreshAction({
    super.key,
    required this.onRefresh,
    this.tooltip = 'Actualiser',
    this.accent,
  });

  @override
  State<RefreshAction> createState() => _RefreshActionState();
}

class _RefreshActionState extends State<RefreshAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _hover = false;
  bool _busy = false;

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        // On laisse le tour se terminer : un arret net en plein mouvement
        // se remarque plus qu'il ne rassure.
        await _spin.forward(from: _spin.value);
        _spin.stop();
        _spin.value = 0;
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accent ?? AppTheme.skyBlue;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: _run,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _hover || _busy
                  ? accent.withValues(alpha: 0.14)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.035)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: RotationTransition(
              turns: _spin,
              child: Icon(
                Icons.refresh_rounded,
                size: 19,
                color: _hover || _busy
                    ? accent
                    : (isDark ? AppTheme.textMutedDark : AppTheme.textMuted),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
