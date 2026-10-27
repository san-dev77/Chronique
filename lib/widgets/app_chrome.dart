import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/tactile.dart';
import '../utils/responsive.dart';

/// Filet de separation qui s'eteint a ses extremites.
///
/// Un trait net d'un bord a l'autre dessine une boite : l'oeil voit le
/// conteneur avant de voir le contenu. En le laissant disparaitre aux
/// extremites, la separation se devine sans s'imposer.
class FadingDivider extends StatelessWidget {
  final Axis axis;
  final Color color;
  final double thickness;

  /// Part de la longueur consacree au degrade, de chaque cote.
  final double fade;

  const FadingDivider({
    super.key,
    this.axis = Axis.horizontal,
    required this.color,
    this.thickness = 1,
    this.fade = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = LinearGradient(
      begin: axis == Axis.horizontal
          ? Alignment.centerLeft
          : Alignment.topCenter,
      end: axis == Axis.horizontal
          ? Alignment.centerRight
          : Alignment.bottomCenter,
      stops: [0, fade, 1 - fade, 1],
      colors: [
        color.withValues(alpha: 0),
        color,
        color,
        color.withValues(alpha: 0),
      ],
    );

    return axis == Axis.horizontal
        ? Container(height: thickness, decoration: BoxDecoration(gradient: gradient))
        : Container(width: thickness, decoration: BoxDecoration(gradient: gradient));
  }
}

/// Un filtre du selecteur segmente.
class FilterSegment {
  final String label;
  final int count;

  const FilterSegment(this.label, this.count);
}

/// Selecteur segmente a curseur glissant.
///
/// Remplace la rangee de pastilles pleines : cinq blocs d'accent saturés
/// criaient plus fort que les chroniques elles-memes. Ici une seule piste
/// discrete, et un curseur clair qui se deplace vers le choix — le mouvement
/// dit ce que la couleur disait avant, sans crier.
class SegmentedFilters extends StatelessWidget {
  final List<FilterSegment> segments;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color accent;
  final bool isDark;

  const SegmentedFilters({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelect,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final count = segments.length;
    if (count == 0) return const SizedBox.shrink();

    // Des segments de largeur egale rendent le deplacement du curseur
    // previsible : il parcourt toujours la meme distance d'un cran a l'autre.
    final position = count == 1 ? 0.0 : -1 + 2 * selected / (count - 1);

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.045)
            : Colors.black.withValues(alpha: 0.032),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Stack(
        children: [
          // Le curseur, derriere les libelles.
          AnimatedAlign(
            duration: AppMotion.medium,
            curve: AppMotion.emphasized,
            alignment: Alignment(position, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / count,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: isDark ? 0.34 : 0.22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.28)
                          : accent.withValues(alpha: 0.14),
                      blurRadius: 9,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: _Segment(
                    segment: segments[i],
                    selected: selected == i,
                    accent: accent,
                    isDark: isDark,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  final FilterSegment segment;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _Segment({
    required this.segment,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final Color fg = selected
        ? widget.accent
        : (_hover
            ? (widget.isDark ? Colors.white : AppTheme.textDark)
            : (widget.isDark ? AppTheme.textMutedDark : AppTheme.textMuted));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          if (!widget.selected) Tactile.selection();
          widget.onTap();
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedDefaultTextStyle(
                  duration: AppMotion.fast,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: selected ? -0.1 : 0,
                    color: fg,
                  ),
                  child: Text(
                    widget.segment.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (widget.segment.count > 0) ...[
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: AppMotion.fast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: selected
                        ? widget.accent.withValues(alpha: 0.14)
                        : (widget.isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : Colors.black.withValues(alpha: 0.05)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.segment.count}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: fg.withValues(alpha: selected ? 1 : 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Petite touche de clavier stylisee, partagee par les en-tetes.
class KbdHint extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color? tint;

  const KbdHint({super.key, required this.label, required this.isDark, this.tint});

  @override
  Widget build(BuildContext context) {
    final base = tint ?? (isDark ? Colors.white : Colors.black);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: base.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: base.withValues(alpha: isDark ? 0.12 : 0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          height: 1.2,
          color: tint ??
              (isDark ? Colors.white38 : AppTheme.textMuted.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}
