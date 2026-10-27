import 'dart:io';

import 'package:flutter/material.dart';

import '../models/note.dart';
import '../models/note_mood.dart';
import '../theme/app_theme.dart';
import '../utils/tactile.dart';
import '../utils/date_formatter.dart';
import '../utils/responsive.dart';
import 'aura_glow_widget.dart';
import 'aura_glow_widget.dart' show AuraSpec;
import 'favorite_toggle.dart';

/// Carte d'une chronique dans la grille.
///
/// Trois choses ont change par rapport a la version precedente, et chacune
/// reparait un defaut precis :
///
/// - la citation ne s'affiche plus dans un encadre bleu code en dur, qui
///   ignorait la couleur d'accent choisie et jurait avec le reste ;
/// - la pastille « Favori » a disparu : le coeur en haut a droite disait
///   deja la meme chose, deux fois plutot qu'une ;
/// - les cartes sans image ne sont plus un aplat avec une bordure grise,
///   mais une surface teintee par l'aura de la note.
class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  bool _hover = false;

  /// Place reservee au coeur, en haut a droite de la carte.
  double get _heartGutter => widget.onFavoriteToggle == null ? 0 : 38;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = note.imagePaths.isNotEmpty;
    final hasAura = NoteMood.hasGlow(note.mood);
    final auraColor = NoteMood.getEffectiveColor(note.mood, note.moodColor);
    final moodData = NoteMood.fromKey(note.mood);

    // La teinte de la carte : l'aura si elle existe, sinon la couleur choisie
    // pour la note. C'est elle qui donne sa personnalite a la vignette.
    final tint = hasAura
        ? auraColor
        : (note.color == Colors.white ? AppTheme.skyBlue : note.color);
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final textColor = hasImage
        ? Colors.white
        : (isDark ? AppTheme.textLight : AppTheme.textDark);

    final card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onSecondaryTap: widget.onLongPress,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.enter,
          transform: Matrix4.identity()..translate(0.0, _hover ? -4.0 : 0.0),
          // Le rognage sur le conteneur, pas dans un ClipRRect interieur : un
          // rayon different laissait passer un liseré d'un pixel au survol.
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hasImage ? Colors.black : null,
            gradient: hasImage
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(surface, tint, isDark ? 0.17 : 0.085)!,
                      surface,
                    ],
                  ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: tint.withValues(
                  alpha: _hover ? 0.42 : (hasImage ? 0.14 : 0.18)),
              width: 1.1,
            ),
            boxShadow: hasAura
                ? null // L'aura s'en charge, et deux ombres se cumuleraient.
                : [
                    BoxShadow(
                      color: _hover
                          ? tint.withValues(alpha: isDark ? 0.30 : 0.22)
                          : Colors.black
                              .withValues(alpha: isDark ? 0.28 : 0.055),
                      blurRadius: _hover ? 26 : 16,
                      offset: Offset(0, _hover ? 11 : 6),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              if (hasImage) ..._image(note, isDark),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasImage && note.imagePaths.length > 1) ...[
                      _photoCount(note.imagePaths.length),
                      const SizedBox(height: 10),
                    ],
                    // Le coeur flotte en haut a droite : le premier bloc de
                    // texte lui laisse la place, sinon il se pose dessus. Une
                    // citation sans titre commence tout en haut de la carte,
                    // et c'est exactement la que le probleme se voyait.
                    if (note.title.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(right: _heartGutter),
                        child: Text(
                          note.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            height: 1.3,
                            color: textColor,
                          ),
                        ),
                      ),
                    if (note.quote != null && note.quote!.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                            right: note.title.isEmpty ? _heartGutter : 0),
                        child: _quote(note.quote!.trim(), tint, textColor,
                            hasImage, note.title.isNotEmpty),
                      ),
                    if (note.content.trim().isNotEmpty) ...[
                      SizedBox(height: note.title.isNotEmpty ? 8 : 0),
                      Text(
                        note.content,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: textColor.withValues(alpha: 0.76),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _footer(
                      note,
                      tint,
                      textColor,
                      hasImage,
                      moodData != null && hasAura
                          ? _auraChip(moodData, auraColor, note.mood, hasImage)
                          : null,
                    ),
                  ],
                ),
              ),
              if (widget.onFavoriteToggle != null)
                Positioned(
                  top: 8,
                  right: 8,
                  // Meme animation que dans l'editeur et la lecture : le geste
                  // se reconnait d'un ecran a l'autre.
                  child: FavoriteBubble(
                    isFavorite: note.isFavorite,
                    onImage: hasImage,
                    tint: textColor,
                    onChanged: (_) {
                      Tactile.toggle();
                      widget.onFavoriteToggle!();
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // RepaintBoundary : une carte qui s'anime (aura, survol) ne force plus
    // le repeint de toute la grille.
    return RepaintBoundary(
      child: hasAura
          ? AuraGlowWidget(
              auraColor: auraColor,
              moodKey: note.mood,
              // Rendu fige dans la grille : dix auras animees en continu
              // coutaient plus cher que tout le reste de l'ecran reuni.
              animated: false,
              enabled: true,
              intensity: 0.7,
              child: card,
            )
          : card,
    );
  }

  // ------------------------------------------------------------- morceaux

  List<Widget> _image(Note note, bool isDark) {
    return [
      Positioned.fill(
        child: AnimatedScale(
          duration: AppMotion.slow,
          curve: AppMotion.enter,
          scale: _hover ? 1.05 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Sans cacheWidth, une photo 1920x1920 est decodee en pleine
              // resolution pour remplir une vignette : ~14,7 Mo par carte.
              final width = constraints.maxWidth;
              int? cacheWidth;
              if (width.isFinite && width > 0) {
                cacheWidth =
                    (width * MediaQuery.devicePixelRatioOf(context)).round();
              }
              return Image.file(
                File(note.imagePaths.first),
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    Container(color: AppTheme.cardDark),
              );
            },
          ),
        ),
      ),
      // Voile : leger en haut, juste de quoi detacher le coeur, et franc en
      // bas, la ou le texte doit se lire. L'ancienne version assombrissait
      // toute la photo a 42 % des le premier pixel.
      Positioned.fill(
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.28, 0.58, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.black.withValues(alpha: 0.04),
                  Colors.black.withValues(alpha: 0.48),
                  Colors.black.withValues(alpha: 0.80),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }

  /// La citation, marquee par un filet dans la teinte de la note.
  ///
  /// L'encadre precedent utilisait `Colors.blue` en dur : il ignorait la
  /// couleur d'accent et encombrait la carte d'une boite de plus.
  Widget _quote(
      String text, Color tint, Color textColor, bool onImage, bool afterTitle) {
    final rule = onImage ? Colors.white.withValues(alpha: 0.65) : tint;
    return Padding(
      padding: EdgeInsets.only(top: afterTitle ? 10 : 0),
      // IntrinsicHeight donne au filet la hauteur du texte voisin. Sans lui,
      // `stretch` reclame une hauteur a une colonne qui n'en impose aucune :
      // la contrainte devient infinie et la carte entiere cesse de
      // s'afficher.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 2.5,
              decoration: BoxDecoration(
                color: rule,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            // Une phrase epinglee se signale jusque dans la grille : c'est
            // la meme marque que dans l'ecran Citations.
            if (widget.note.isPinned) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 6),
                child: Icon(Icons.push_pin_rounded,
                    size: 12, color: rule.withValues(alpha: 0.9)),
              ),
            ],
            Expanded(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.88),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoCount(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.photo_library_rounded,
              color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text('$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  height: 1.2,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  /// Pastille d'aura, en verre teinte plutot qu'en aplat sature.
  Widget _auraChip(
      NoteMood moodData, Color auraColor, String? moodKey, bool onImage) {
    return Tooltip(
      message: '${moodData.label} — ${AuraSpec.describe(moodKey)}',
      waitDuration: const Duration(milliseconds: 350),
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: _hover ? 1 : 0.82,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
          decoration: BoxDecoration(
            color: onImage
                ? Colors.black.withValues(alpha: 0.34)
                : auraColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: onImage
                  ? Colors.white.withValues(alpha: 0.22)
                  : auraColor.withValues(alpha: 0.40),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: auraColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: auraColor.withValues(alpha: 0.8),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                moodData.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onImage
                      ? Colors.white
                      : Color.lerp(auraColor, Colors.black, 0.45),
                  fontSize: 8.5,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Le pied de carte : la date, et ce qui la complete a droite.
  ///
  /// La pastille d'aura vivait en surimpression, dans le coin : sur une carte
  /// etroite elle se posait sur la date. Ici elle prend sa place dans la
  /// rangee, et plus rien ne se chevauche.
  Widget _footer(Note note, Color tint, Color textColor, bool onImage,
      Widget? auraChip) {
    final muted = textColor.withValues(alpha: 0.55);
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 12, color: muted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            // La date d'une chronique, c'est celle du souvenir — pas celle
            // de la derniere retouche.
            DateFormatter.formatRelativeDate(note.createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Pas de Spacer : il prenait toute la place restante et ne laissait
        // rien a l etiquette, qui debordait alors de la carte. Les deux
        // elements se partagent la rangee et se raccourcissent ensemble.
        if (auraChip != null)
          Flexible(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: auraChip),
          )
        else ...[
          const Spacer(),
          // L'invitation n'apparait qu'au survol : elle ne charge pas la carte
          // au repos, mais indique quoi faire une fois la souris dessus.
          AnimatedOpacity(
            duration: AppMotion.fast,
            opacity: _hover ? 1 : 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lire',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: onImage ? Colors.white : tint,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded,
                    size: 13, color: onImage ? Colors.white : tint),
              ],
            ),
          ),
        ],
      ],
    );
  }

}
