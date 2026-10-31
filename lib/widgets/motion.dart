/// Pièces de mouvement partagées.
///
/// **Une règle gouverne tout ce fichier** : on n'animera que des
/// transformations et des opacités. Ce sont les deux seules choses qu'un GPU
/// d'entrée de gamme compose sans recalculer la scène. Animer un flou
/// (`BackdropFilter`), un rayon d'ombre ou une bordure oblige le moteur à
/// repeindre à chaque image — sur le Galaxy A04e visé, c'est la différence
/// entre soixante images par seconde et vingt.
///
/// Autrement dit : l'immersion se gagne par le déplacement et la
/// transparence, pas par les effets coûteux. Le gain est aussi visuel —
/// un mouvement qui ne saccade pas paraît plus soigné qu'un effet riche
/// qui hache.
library;

import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Durées propres à l'entrée en scène, plus lentes que les réactions
/// immédiates d'[AppMotion] : une apparition se savoure, un appui se subit.
class RevealMotion {
  const RevealMotion._();

  /// Durée d'apparition d'un élément.
  static const Duration duree = Duration(milliseconds: 460);

  /// Décalage entre deux éléments voisins.
  static const Duration pas = Duration(milliseconds: 55);

  /// Au-delà, l'attente devient perceptible : le douzième élément d'une
  /// liste ne doit pas arriver une seconde après le premier.
  static const Duration retardMax = Duration(milliseconds: 420);

  /// Distance parcourue vers le haut pendant l'apparition.
  static const double montee = 18;

  /// Retard d'un élément selon son rang, borné.
  static Duration retardPour(int index) {
    final brut = pas * index;
    return brut > retardMax ? retardMax : brut;
  }
}

/// Fait entrer son enfant : il monte de quelques pixels en apparaissant.
///
/// L'apparition ne joue **qu'une fois**. Les grilles à `itemBuilder`
/// recyclent leurs éléments : sans cette garde, une carte rejouait son
/// entrée chaque fois qu'on repassait devant elle, ce qui donnait une liste
/// clignotante au défilement. C'est à l'appelant de retenir ce qui a déjà
/// été montré — voir le `Set` d'identifiants dans l'écran des chroniques.
class Reveal extends StatefulWidget {
  final Widget child;

  /// Rang dans la série, pour l'effet de cascade.
  final int index;

  /// `false` pour afficher immédiatement, sans animation : un élément déjà
  /// vu, ou le réglage système « réduire les animations ».
  final bool animate;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.animate = true,
  });

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: RevealMotion.duree,
    // Un élément non animé part déjà arrivé.
    value: widget.animate ? 0 : 1,
  );

  late final Animation<double> _courbe = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  @override
  void initState() {
    super.initState();
    if (!widget.animate) return;

    // Le depart est reporte apres la premiere image. `MediaQuery` consulte
    // un widget herite, ce qui est interdit depuis initState : pour un rang
    // 0, il n'y a aucune attente et l'appel serait synchrone — Flutter
    // levait alors une exception et l'apparition ne partait jamais, laissant
    // la carte definitivement transparente.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _lancer();
    });
  }

  Future<void> _lancer() async {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
      return;
    }

    final retard = RevealMotion.retardPour(widget.index);
    if (retard > Duration.zero) {
      await Future<void>.delayed(retard);
      if (!mounted) return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _courbe,
      // L'enfant est passé à part : il n'est pas reconstruit à chaque image,
      // seul le FractionalTranslation l'est.
      child: widget.child,
      builder: (context, child) {
        final t = _courbe.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * RevealMotion.montee),
            child: child,
          ),
        );
      },
    );
  }
}

/// Rétrécit légèrement son enfant pendant l'appui.
///
/// Un retour visuel immédiat vaut mieux qu'une animation d'ouverture
/// soignée : c'est lui qui donne le sentiment que l'interface répond. Le
/// geste reste transmis à l'enfant, donc ce widget s'insère sans rien
/// casser des gestes existants.
class PressScale extends StatefulWidget {
  final Widget child;

  /// Échelle atteinte pendant l'appui. Très proche de 1 : au-delà, l'effet
  /// cesse d'être un retour et devient une animation.
  final double scale;

  /// `null` laisse le widget purement décoratif, sans capter de geste.
  final VoidCallback? onTap;

  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.975,
    this.onTap,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      // Le doigt qui part en glissade annule l'appui : sans cela, une carte
      // restait enfoncee quand on commencait a faire defiler depuis elle.
      behavior: HitTestBehavior.deferToChild,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Déplace son enfant plus lentement que le défilement.
///
/// L'image d'en-tête d'une chronique reste ainsi un peu en arrière quand le
/// texte monte : c'est ce décalage qui donne la profondeur, et il ne coûte
/// qu'une translation.
///
/// Le widget s'abonne au [ScrollController] plutôt que de passer par un
/// `setState` de l'écran : seule l'image est reconstruite à chaque image,
/// pas la page entière.
class Parallax extends StatelessWidget {
  final ScrollController controller;
  final Widget child;

  /// Part du défilement répercutée. 0,3 veut dire que l'image monte à trois
  /// dixièmes de la vitesse du texte.
  final double facteur;

  /// Déplacement maximal, pour que l'image ne quitte jamais son cadre.
  final double maximum;

  const Parallax({
    super.key,
    required this.controller,
    required this.child,
    this.facteur = 0.3,
    this.maximum = 60,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        if (!controller.hasClients) return child!;

        // Seul le defilement vers le bas decale l'image : en rebond vers le
        // haut, elle resterait collee au bord et laisserait un vide.
        final offset = controller.offset;
        final decalage = (offset <= 0 ? 0.0 : offset * facteur).clamp(0.0, maximum);

        return Transform.translate(
          offset: Offset(0, decalage),
          child: child,
        );
      },
    );
  }
}
