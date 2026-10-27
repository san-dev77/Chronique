import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Points de rupture de l'application.
///
/// L'app etait entierement calculee pour un telephone puis etiree sur desktop.
/// Tout ce qui depend de la largeur passe desormais par ici.
enum Breakpoint { compact, medium, expanded, large }

class Responsive {
  const Responsive._();

  static const double mediumMin = 640;
  static const double expandedMin = 1024;
  static const double largeMin = 1440;

  /// Largeur maximale du contenu. Au-dela, on centre plutot que d'etirer :
  /// une grille de notes large de 2000 px n'est pas lisible.
  static const double contentMaxWidth = 1360;

  static Breakpoint fromWidth(double width) {
    if (width >= largeMin) return Breakpoint.large;
    if (width >= expandedMin) return Breakpoint.expanded;
    if (width >= mediumMin) return Breakpoint.medium;
    return Breakpoint.compact;
  }

  static Breakpoint of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  /// Vrai des qu'on quitte la mise en page telephone.
  static bool isWide(BuildContext context) => of(context) != Breakpoint.compact;

  /// La barre laterale remplace la barre du bas.
  static bool useSidebar(double width) => fromWidth(width) != Breakpoint.compact;

  /// La barre laterale affiche les libelles a cote des icones.
  static bool useExtendedSidebar(double width) {
    final b = fromWidth(width);
    return b == Breakpoint.expanded || b == Breakpoint.large;
  }

  /// Nombre de colonnes de la grille de notes, pour une largeur *disponible*
  /// (barre laterale deja deduite).
  static int noteColumns(double width) {
    if (width >= 1400) return 5;
    if (width >= 1020) return 4;
    if (width >= 700) return 3;
    // Seuil bas : un telephone fait ~412 px logiques, dont 40 de marges.
    // A 420 il retombait a une seule colonne, alors qu'il en affichait deux.
    if (width >= 300) return 2;
    return 1;
  }

  static double gutter(double width) =>
      fromWidth(width) == Breakpoint.compact ? 14 : 20;

  /// Marge horizontale de page.
  static double horizontalPadding(double width) {
    switch (fromWidth(width)) {
      case Breakpoint.compact:
        return 20;
      case Breakpoint.medium:
        return 28;
      case Breakpoint.expanded:
        return 36;
      case Breakpoint.large:
        return 44;
    }
  }

  /// Marge qui borne *et* centre le contenu dans un sliver.
  static EdgeInsets contentInsets(double width) {
    final base = horizontalPadding(width);
    final overflow = width - contentMaxWidth;
    final extra = overflow > 0 ? overflow / 2 : 0.0;
    return EdgeInsets.symmetric(horizontal: base + extra);
  }
}

/// Centre et borne le contenu pour qu'il ne s'etire pas sur grand ecran.
class ContentBounds extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ContentBounds({
    super.key,
    required this.child,
    this.maxWidth = Responsive.contentMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Autorise le glisser-deposer a la souris et garde la barre de defilement
/// visible : sans cela, une fenetre desktop ne defile qu'a la molette.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Courbes et durees communes, pour que toute l'app bouge de la meme maniere.
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 140);
  static const Duration medium = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  /// Decelere franchement puis se pose : la courbe qui donne l'impression
  /// qu'un element « arrive » au lieu de simplement apparaitre.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasized = Curves.easeOutQuart;
}
