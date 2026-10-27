import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'app_chrome.dart';

/// Une destination de navigation, partagee par la barre laterale (desktop)
/// et la barre du bas (mobile), pour qu'elles ne divergent jamais.
class AppDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? shortcut;

  const AppDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.shortcut,
  });

  static const List<AppDestination> all = [
    AppDestination(
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
      label: 'Chroniques',
      shortcut: 'Ctrl+1',
    ),
    AppDestination(
      icon: Icons.bolt_outlined,
      activeIcon: Icons.bolt_rounded,
      label: 'Étincelles',
      shortcut: 'Ctrl+2',
    ),
    AppDestination(
      icon: Icons.format_quote_outlined,
      activeIcon: Icons.format_quote_rounded,
      label: 'Citations',
      shortcut: 'Ctrl+3',
    ),
    AppDestination(
      icon: Icons.people_outline_rounded,
      activeIcon: Icons.people_rounded,
      label: 'Partage',
      shortcut: 'Ctrl+4',
    ),
    AppDestination(
      icon: Icons.auto_awesome_outlined,
      activeIcon: Icons.auto_awesome_rounded,
      label: 'Souvenirs',
      shortcut: 'Ctrl+5',
    ),
    AppDestination(
      icon: Icons.favorite_outline_rounded,
      activeIcon: Icons.favorite_rounded,
      label: 'Favoris',
      shortcut: 'Ctrl+6',
    ),
    AppDestination(
      icon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
      label: 'Albums',
      shortcut: 'Ctrl+7',
    ),
    AppDestination(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Réglages',
      shortcut: 'Ctrl+8',
    ),
  ];
}

/// Mesures de la barre laterale.
///
/// Tout part d'ici : la marque, le bouton de creation, les destinations et le
/// curseur. Un seul endroit decide, donc rien ne peut se decaler — c'est
/// precisement ce qui clochait quand la mise en page et le curseur comptaient
/// chacun de leur cote.
class _Rail {
  const _Rail._();

  /// Marge laterale de la zone de navigation.
  static const double inset = 12;

  /// Retrait interieur d'une rangee, avant la plaque d'icone.
  static const double rowPadding = 10;

  /// Cote de la plaque qui porte l'icone — la meme pour la marque, le bouton
  /// de creation et les destinations : c'est elle qui aligne la colonne de
  /// texte sur toute la hauteur de la barre.
  static const double plate = 36;

  /// Espace entre la plaque et le texte.
  static const double plateGap = 12;

  static const double rowHeight = 46;
  static const double rowGap = 4;
  static const double pitch = rowHeight + rowGap;

  /// Hauteur d'une coupure entre deux groupes.
  static const double breakExtended = 30;
  static const double breakCollapsed = 20;

  /// Premiere destination de chaque groupe, et son intitule.
  static const List<int> groupStarts = [0, 3, 7];
  static const List<String?> groupLabels = ['Écrire', 'Explorer', null];

  /// Distance entre le haut du rail et la destination [index].
  static double offsetOf(int index, bool extended) {
    var top = index * pitch;
    for (var g = 1; g < groupStarts.length; g++) {
      if (index >= groupStarts[g]) {
        top += extended ? breakExtended : breakCollapsed;
      }
    }
    return top;
  }

  /// Hauteur exacte du rail : le bas de la derniere rangee, sans marge
  /// orpheline. C'est l'oubli de cette marge qui faisait deborder Reglages.
  static double height(bool extended) =>
      offsetOf(AppDestination.all.length - 1, extended) + rowHeight;
}

/// Barre laterale de l'application desktop.
///
/// Deux etats : repliee (icones seules) entre 640 et 1024 px, depliee
/// (icones + libelles) au-dela.
class AppSidebar extends StatelessWidget {
  static const double collapsedWidth = 82;
  static const double expandedWidth = 254;

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool extended;
  final int sharedBadge;
  final VoidCallback? onCompose;
  final Widget? footer;

  const AppSidebar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.extended,
    this.sharedBadge = 0,
    this.onCompose,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.skyBlue;
    final surface = isDark ? AppTheme.surfaceDark : Colors.white;

    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      width: extended ? expandedWidth : collapsedWidth,
      // Une surface qui respire : l'accent affleure en haut, derriere la
      // marque, puis s'efface. Un aplat uniforme se lisait comme un panneau
      // colle a cote du contenu.
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.30, 1],
          colors: [
            Color.lerp(surface, accent, isDark ? 0.07 : 0.035)!,
            surface,
            isDark ? Color.lerp(surface, Colors.black, 0.20)! : surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Brand(extended: extended, accent: accent, isDark: isDark),
              if (onCompose != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      _Rail.inset, 0, _Rail.inset, 14),
                  child: _ComposeButton(
                    extended: extended,
                    accent: accent,
                    onTap: onCompose!,
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: _Rail.inset),
                  child: _NavRail(
                    currentIndex: currentIndex,
                    onSelect: onSelect,
                    extended: extended,
                    accent: accent,
                    isDark: isDark,
                    sharedBadge: sharedBadge,
                  ),
                ),
              ),
              if (footer != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: _Rail.inset),
                  child: SizedBox(height: 12),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: _Rail.inset + 2),
                  child: FadingDivider(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                    fade: 0.1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      _Rail.inset + 2, 12, _Rail.inset + 2, 16),
                  child: footer!,
                ),
              ],
            ],
          ),
          // La separation d'avec le contenu : un filet qui s'eteint en haut et
          // en bas plutot qu'une arete franche sur toute la hauteur.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: FadingDivider(
              axis: Axis.vertical,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : accent.withValues(alpha: 0.16),
              fade: 0.12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Le rail de navigation et son curseur.
///
/// Les rangees sont posees a une hauteur calculee, pas empilees : le curseur
/// lit les memes mesures qu'elles, il tombe donc toujours juste.
class _NavRail extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool extended;
  final Color accent;
  final bool isDark;
  final int sharedBadge;

  const _NavRail({
    required this.currentIndex,
    required this.onSelect,
    required this.extended,
    required this.accent,
    required this.isDark,
    required this.sharedBadge,
  });

  @override
  State<_NavRail> createState() => _NavRailState();
}

class _NavRailState extends State<_NavRail>
    with SingleTickerProviderStateMixin {
  /// Les destinations se posent l'une apres l'autre au lancement.
  ///
  /// Jouee une seule fois, a l'ouverture : l'etat survit aux
  /// reconstructions de la barre, l'animation ne se rejoue donc pas a
  /// chaque changement d'onglet — ce serait vite insupportable.
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  /// Fenetre d'animation du [index]-ieme element.
  Animation<double> _slot(int index, int total) {
    final start = (index / total) * 0.55;
    return CurvedAnimation(
      parent: _reveal,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: AppMotion.enter),
    );
  }

  Widget _appear(int index, int total, Widget child) {
    final slot = _slot(index, total);
    return AnimatedBuilder(
      animation: slot,
      builder: (context, _) => Opacity(
        opacity: slot.value,
        child: Transform.translate(
          offset: Offset(-10 * (1 - slot.value), 0),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.currentIndex;
    final extended = widget.extended;
    final accent = widget.accent;
    final isDark = widget.isDark;
    final layers = <Widget>[];
    final breakHeight =
        extended ? _Rail.breakExtended : _Rail.breakCollapsed;

    // Les coupures d'abord : elles vivent dans l'espace laisse avant le
    // premier element de leur groupe.
    for (var g = 1; g < _Rail.groupStarts.length; g++) {
      final start = _Rail.groupStarts[g];
      layers.add(Positioned(
        left: 0,
        right: 0,
        top: _Rail.offsetOf(start, extended) - breakHeight,
        height: breakHeight,
        child: _appear(
          start,
          AppDestination.all.length,
          _GroupBreak(
            label: extended ? _Rail.groupLabels[g] : null,
            isDark: isDark,
          ),
        ),
      ));
    }

    // Le curseur, derriere les rangees : un seul pour les sept destinations,
    // il se deplace vers le choix au lieu d'apparaitre a sa place. C'est ce
    // trajet qui raconte la navigation.
    layers.add(AnimatedPositioned(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      left: -_Rail.inset,
      top: _Rail.offsetOf(currentIndex, extended) + 13,
      height: _Rail.rowHeight - 26,
      width: 3.5,
      child: Container(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: const BorderRadius.horizontal(
            right: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.55),
              blurRadius: 10,
              offset: const Offset(1, 0),
            ),
          ],
        ),
      ),
    ));

    for (var i = 0; i < AppDestination.all.length; i++) {
      layers.add(Positioned(
        left: 0,
        right: 0,
        top: _Rail.offsetOf(i, extended),
        height: _Rail.rowHeight,
        child: _appear(
          i,
          AppDestination.all.length,
          _SidebarItem(
            destination: AppDestination.all[i],
            selected: currentIndex == i,
            extended: extended,
            accent: accent,
            isDark: isDark,
            // Partage est en 4e position depuis l'arrivee des Citations.
            badge: i == 3 ? widget.sharedBadge : 0,
            onTap: () => widget.onSelect(i),
          ),
        ),
      ));
    }

    return SizedBox(
      height: _Rail.height(extended),
      child: Stack(clipBehavior: Clip.none, children: layers),
    );
  }
}

/// Coupure entre deux groupes de destinations.
class _GroupBreak extends StatelessWidget {
  final String? label;
  final bool isDark;

  const _GroupBreak({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (label == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FadingDivider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(
          left: _Rail.inset + _Rail.rowPadding, bottom: 7),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          label!.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark
                ? Colors.white.withValues(alpha: 0.30)
                : AppTheme.textMuted.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

/// Plaque d'icone : le motif commun de la marque, du bouton de creation et
/// des destinations. Sa largeur fixe la colonne de texte.
class _Plate extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? color;
  final List<BoxShadow>? shadow;
  final double radius;

  const _Plate({
    required this.child,
    this.gradient,
    this.color,
    this.shadow,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _Rail.plate,
      height: _Rail.plate,
      decoration: BoxDecoration(
        gradient: gradient,
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
      ),
      child: gradient == null
          ? Center(child: child)
          // Un reflet en haut : sans lui le degrade reste plat et la plaque
          // ressemble a un carre de couleur.
          : Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _Rail.plate * 0.5,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(radius),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.24),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                Center(child: child),
              ],
            ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool extended;
  final Color accent;
  final bool isDark;

  const _Brand({
    required this.extended,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final plate = _Plate(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(accent, Colors.white, 0.18)!,
          Color.lerp(accent, Colors.black, 0.28)!,
        ],
      ),
      shadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.40),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
      radius: 13,
      child: const Icon(Icons.auto_stories_rounded,
          color: Colors.white, size: 20),
    );

    if (!extended) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 20),
        child: Center(child: plate),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          _Rail.inset + _Rail.rowPadding, 24, _Rail.inset, 20),
      child: Row(
        children: [
          plate,
          const SizedBox(width: _Rail.plateGap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chroniques',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.15,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'The Story Box',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                    height: 1.5,
                    color: isDark
                        ? AppTheme.textMutedDark.withValues(alpha: 0.8)
                        : AppTheme.textMuted.withValues(alpha: 0.75),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bouton de creation, mis en avant en haut de la barre : sur desktop le
/// bouton flottant en bas a droite n'est pas la ou l'oeil le cherche.
class _ComposeButton extends StatefulWidget {
  final bool extended;
  final Color accent;
  final VoidCallback onTap;

  const _ComposeButton({
    required this.extended,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ComposeButton> createState() => _ComposeButtonState();
}

class _ComposeButtonState extends State<_ComposeButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;

    final button = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedScale(
          // Un bouton qui s'enfonce sous le doigt confirme le clic avant
          // meme que l'ecran ne change.
          scale: _down ? 0.975 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, _hover ? 0.18 : 0.08)!,
                  Color.lerp(accent, Colors.black, 0.24)!,
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _hover ? 0.46 : 0.28),
                  blurRadius: _hover ? 20 : 12,
                  offset: Offset(0, _hover ? 7 : 4),
                ),
              ],
            ),
            // Sans alignement explicite, un Stack pose ses enfants non
            // positionnes en haut a gauche : le libelle se retrouvait colle
            // au bord superieur du bouton au lieu d'etre centre.
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 23,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.22),
                          Colors.white.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.extended)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: _Rail.rowPadding),
                    child: Row(
                      children: [
                        // L'icone occupe la meme largeur qu'une plaque : son
                        // libelle tombe donc sur la colonne de texte commune.
                        const SizedBox(
                          width: _Rail.plate,
                          child: Icon(Icons.add_rounded,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: _Rail.plateGap),
                        const Expanded(
                          child: Text(
                            'Nouvelle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        KbdHint(
                          label: 'Ctrl N',
                          isDark: true,
                          tint: Colors.white.withValues(alpha: 0.80),
                        ),
                      ],
                    ),
                  )
                else
                  const Center(
                    child: Icon(Icons.add_rounded,
                        color: Colors.white, size: 22),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.extended) return button;
    return Tooltip(
      message: 'Nouvelle chronique  ·  Ctrl+N',
      waitDuration: const Duration(milliseconds: 420),
      child: button,
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final AppDestination destination;
  final bool selected;
  final bool extended;
  final Color accent;
  final bool isDark;
  final int badge;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.extended,
    required this.accent,
    required this.isDark,
    required this.badge,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final accent = widget.accent;
    final isDark = widget.isDark;

    final Color foreground = selected
        ? (isDark ? Colors.white : Color.lerp(accent, Colors.black, 0.32)!)
        : (_hover
            ? (isDark ? Colors.white70 : AppTheme.textDark)
            : (isDark ? AppTheme.textMutedDark : AppTheme.textMuted));

    // L'element choisi n'est plus un pave d'accent sature : une teinte qui
    // s'eclaircit vers la droite suffit, des lors que le curseur, la plaque
    // et le poids du texte disent la meme chose. La lumiere semble venir du
    // rail, la ou se trouve le curseur.
    final Gradient? background = selected
        ? LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              accent.withValues(alpha: isDark ? 0.20 : 0.12),
              accent.withValues(alpha: isDark ? 0.08 : 0.04),
            ],
          )
        : null;

    Widget plate = _Plate(
      gradient: selected
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accent, Colors.white, 0.14)!,
                Color.lerp(accent, Colors.black, 0.26)!,
              ],
            )
          : null,
      color: selected
          ? null
          : (_hover
              ? (isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.04))
              : Colors.transparent),
      shadow: selected
          ? [
              BoxShadow(
                color: accent.withValues(alpha: 0.42),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
          : null,
      child: Icon(
        selected ? widget.destination.activeIcon : widget.destination.icon,
        size: 19,
        color: selected ? Colors.white : foreground,
      ),
    );

    if (widget.badge > 0) {
      plate = Stack(
        clipBehavior: Clip.none,
        children: [
          plate,
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE05252),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? AppTheme.surfaceDark : Colors.white,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE05252).withValues(alpha: 0.45),
                    blurRadius: 7,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.badge > 9 ? '9+' : '${widget.badge}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      );
    }

    Widget row = AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      decoration: BoxDecoration(
        gradient: background,
        color: selected
            ? null
            : (_hover
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.045)
                    : Colors.black.withValues(alpha: 0.028))
                : Colors.transparent),
        borderRadius: BorderRadius.circular(13),
      ),
      child: widget.extended
          ? Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: _Rail.rowPadding),
              child: Row(
                children: [
                  plate,
                  const SizedBox(width: _Rail.plateGap),
                  Expanded(
                    child: Text(
                      widget.destination.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                        letterSpacing: selected ? -0.2 : 0,
                      ),
                    ),
                  ),
                  if (widget.destination.shortcut != null)
                    AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: _hover || selected ? 1 : 0,
                      child: KbdHint(
                        label: widget.destination.shortcut!
                            .replaceAll('+', ' '),
                        isDark: isDark,
                        tint: selected ? accent : null,
                      ),
                    ),
                ],
              ),
            )
          : Center(child: plate),
    );

    row = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: row,
      ),
    );

    if (widget.extended) return row;

    return Tooltip(
      message: widget.destination.shortcut == null
          ? widget.destination.label
          : '${widget.destination.label}  ·  ${widget.destination.shortcut}',
      waitDuration: const Duration(milliseconds: 420),
      child: row,
    );
  }
}
