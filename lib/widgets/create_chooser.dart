import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Ce que l'on vient d'ecrire.
enum CreateKind { note, quote, spark }

/// Demande ce que l'on veut creer.
///
/// Les trois formes ne se ressemblent pas : une chronique se raconte, une
/// citation se recueille, une etincelle se jette. Les confondre derriere un
/// seul bouton obligeait a entrer dans l'editeur complet pour trois mots.
///
/// Boite centree sur desktop, feuille glissante sur telephone. Renvoie `null`
/// si l'on renonce.
Future<CreateKind?> showCreateChooser(
  BuildContext context, {
  Widget? inspiration,
}) {
  if (Responsive.isWide(context)) {
    return showDialog<CreateKind>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: _Chooser(inspiration: inspiration, rounded: true),
        ),
      ),
    );
  }

  return showModalBottomSheet<CreateKind>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _Chooser(inspiration: inspiration, rounded: false),
  );
}

class _Chooser extends StatelessWidget {
  final Widget? inspiration;
  final bool rounded;

  const _Chooser({required this.inspiration, required this.rounded});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.surfaceDark : Colors.white;
    final accent = AppTheme.skyBlue;

    final cards = [
      _ChoiceCard(
        kind: CreateKind.note,
        icon: Icons.auto_stories_rounded,
        title: 'Chronique',
        subtitle: 'Un récit, avec ses images',
        color: accent,
      ),
      _ChoiceCard(
        kind: CreateKind.quote,
        icon: Icons.format_quote_rounded,
        title: 'Citation',
        subtitle: 'Une phrase à garder',
        color: const Color(0xFF8B6FD6),
      ),
      _ChoiceCard(
        kind: CreateKind.spark,
        icon: Icons.bolt_rounded,
        title: 'Étincelle',
        subtitle: 'Une idée, vite notée',
        color: const Color(0xFFE09B3D),
      ),
    ];

    return Container(
      padding: EdgeInsets.fromLTRB(22, rounded ? 22 : 12, 22, rounded ? 24 : 34),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.35, 1],
          colors: [
            Color.lerp(surface, accent, isDark ? 0.08 : 0.04)!,
            surface,
            surface,
          ],
        ),
        borderRadius: rounded
            ? BorderRadius.circular(26)
            : const BorderRadius.vertical(top: Radius.circular(30)),
        border: rounded
            ? Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : accent.withValues(alpha: 0.12))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
            blurRadius: 30,
            offset: Offset(0, rounded ? 14 : -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!rounded)
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20, top: 6),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          if (inspiration != null) ...[
            inspiration!,
            const SizedBox(height: 20),
            Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Text(
                'Qu’écrivez-vous ?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // En colonne sur telephone : trois cartes cote a cote a 375 px
          // auraient ecrase les libelles.
          if (Responsive.isWide(context))
            Row(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            )
          else
            Column(
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  cards[i],
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatefulWidget {
  final CreateKind kind;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _ChoiceCard({
    required this.kind,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.color;
    final wide = Responsive.isWide(context);

    final plate = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(color, Colors.white, 0.16)!,
            Color.lerp(color, Colors.black, 0.24)!,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: _hover ? 0.46 : 0.28),
            blurRadius: _hover ? 16 : 10,
            offset: Offset(0, _hover ? 6 : 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
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
          Icon(widget.icon, color: Colors.white, size: 22),
        ],
      ),
    );

    final texts = Column(
      crossAxisAlignment:
          wide ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: isDark ? Colors.white : AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.subtitle,
          textAlign: wide ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
          ),
        ),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => Navigator.pop(context, widget.kind),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          transform: Matrix4.identity()..translate(0.0, _hover ? -3.0 : 0.0),
          padding: EdgeInsets.all(wide ? 18 : 14),
          decoration: BoxDecoration(
            color: _hover
                ? color.withValues(alpha: isDark ? 0.14 : 0.07)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.045)
                    : Colors.black.withValues(alpha: 0.028)),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover
                  ? color.withValues(alpha: 0.34)
                  : Colors.transparent,
            ),
          ),
          child: wide
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    plate,
                    const SizedBox(height: 12),
                    texts,
                  ],
                )
              : Row(
                  children: [
                    plate,
                    const SizedBox(width: 14),
                    Expanded(child: texts),
                    Icon(Icons.chevron_right_rounded,
                        size: 19,
                        color: _hover
                            ? color
                            : (isDark ? Colors.white38 : Colors.black26)),
                  ],
                ),
        ),
      ),
    );
  }
}
