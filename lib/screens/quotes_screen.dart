import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../models/note.dart';
import '../models/note_mood.dart';
import '../services/note_service.dart';
import '../theme/app_theme.dart';
import '../utils/tactile.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive.dart';
import '../widgets/favorite_toggle.dart';
import '../widgets/save_flash.dart';
import '../widgets/screen_header.dart';
import 'quote_edit_screen.dart';

/// L'espace des citations.
///
/// Une citation n'a pas besoin d'une carte de chronique : pas d'image, pas
/// d'extrait, pas de date en gros. Elle a besoin d'air autour de sa phrase.
/// D'ou cet ecran a part, ou la typographie fait le travail que l'illustration
/// fait ailleurs.
///
/// Les citations sont les chroniques qui portent une phrase : celles ecrites
/// ici, et celles qui dormaient deja dans d'anciennes chroniques.
class QuotesScreen extends StatefulWidget {
  const QuotesScreen({super.key});

  @override
  State<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends State<QuotesScreen> {
  List<Note> _quotes = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // L'ecran reste vivant dans l'IndexedStack : il se remet a jour quand une
    // citation change ailleurs, ou qu'une note en recoit une.
    NoteService.instance.revision.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    NoteService.instance.revision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _quotes = _collect());
  }

  List<Note> _collect() {
    final all = NoteService.instance.getAllNotes();
    return all
        .where((n) => n.quote != null && n.quote!.trim().isNotEmpty)
        .toList()
      // Les phrases epinglees remontent : ce sont celles qu'on revient
      // chercher. Le reste suit l'ordre du temps.
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await NoteService.instance.waitReady();
      _quotes = _collect();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Note note, {bool isNew = false}) async {
    await NoteService.instance.saveNote(note, isNew: isNew);
  }

  void _create() {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(QuoteEditScreen(onSave: _save)),
    );
  }

  void _edit(Note note) {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(
        QuoteEditScreen(note: note, onSave: _save),
      ),
    );
  }

  Future<void> _delete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette citation ?'),
        content: Text(
          note.content.trim().isEmpty
              ? 'La phrase sera effacée définitivement.'
              : 'Cette chronique contient aussi du texte : seule la citation '
                  'sera retirée, la chronique reste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Une citation seule s'efface ; une citation posee dans une chronique
    // ecrite se retire sans emporter le texte avec elle.
    if (note.content.trim().isEmpty) {
      await NoteService.instance.deleteNote(note.id);
    } else {
      await NoteService.instance.saveNote(note.copyWith(quote: ''));
    }
    if (mounted) await showDeleteFlash(context);
  }

  void _toggleFavorite(Note note) {
    Tactile.toggle();
    note.isFavorite = !note.isFavorite;
    NoteService.instance.saveNote(note, touch: false);
  }

  /// Epingle ou decroche une phrase.
  ///
  /// Epingler n'est pas modifier : la date de la chronique ne bouge pas.
  void _togglePin(Note note) {
    Tactile.toggle();
    NoteService.instance.saveNote(
      note.copyWith(isPinned: !note.isPinned),
      touch: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final wide = Responsive.useSidebar(width);

      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              screenHeaderSliver(
                width: width,
                pinnedHeight: 116,
                header: ScreenHeader(
                  width: width,
                  // Presente comme onglet dans la barre laterale, mais aussi
                  // empilee depuis le bandeau des Chroniques sur telephone :
                  // la fleche n'apparait que dans le second cas.
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.pop(context)
                      : null,
                  icon: Icons.format_quote_rounded,
                  title: 'Citations',
                  subtitle: _quotes.isEmpty
                      ? 'Les phrases que vous voulez garder'
                      : '${_quotes.length} phrase${_quotes.length > 1 ? 's' : ''} gardée${_quotes.length > 1 ? 's' : ''}',
                  accent: AppTheme.skyBlue,
                  actions: [
                    if (wide)
                      _AddQuoteButton(
                        accent: AppTheme.skyBlue,
                        onTap: _create,
                      ),
                  ],
                ),
              ),
              _buildContent(isDark, width),
            ],
          ),
        ),
        floatingActionButton: wide
            ? null
            : FloatingActionButton.extended(
                heroTag: 'fab_quotes',
                onPressed: _create,
                backgroundColor: AppTheme.skyBlue,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.format_quote_rounded),
                label: const Text('Citation',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
      );
    });
  }

  Widget _buildContent(bool isDark, double width) {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_quotes.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _buildEmpty(isDark),
      );
    }

    final insets = Responsive.contentInsets(width);
    // Moins de colonnes que pour les chroniques : une phrase a besoin d'une
    // largeur de lecture, pas d'une vignette.
    final columns = width >= 1500
        ? 4
        : width >= 1100
            ? 3
            : width >= 700
                ? 2
                : 1;

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(insets.left, 22, insets.right, 110),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childCount: _quotes.length,
        itemBuilder: (context, i) {
          final note = _quotes[i];
          return _QuoteCard(
            key: ValueKey(note.id),
            note: note,
            isDark: isDark,
            onTap: () => _edit(note),
            onDelete: () => _delete(note),
            onToggleFavorite: () => _toggleFavorite(note),
            onTogglePin: () => _togglePin(note),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.skyBlue.withValues(alpha: 0.10),
                ),
                child: Icon(Icons.format_quote_rounded,
                    size: 42, color: AppTheme.skyBlue.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 22),
              Text(
                'Aucune citation pour l’instant',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Une phrase lue quelque part, une parole qu’on ne veut pas '
                'perdre : elle a sa place ici, sans avoir à écrire une '
                'chronique autour.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              _AddQuoteButton(
                accent: AppTheme.skyBlue,
                onTap: _create,
                expanded: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Carte d'une citation : la phrase, et le minimum autour.
class _QuoteCard extends StatefulWidget {
  final Note note;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePin;

  const _QuoteCard({
    super.key,
    required this.note,
    required this.isDark,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onTogglePin,
  });

  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final isDark = widget.isDark;
    final tint = note.moodColor != null
        ? Color(note.moodColor!)
        : (NoteMood.palette.first);
    final author = note.title.trim();
    final pinned = note.isPinned;

    // Une phrase epinglee ne se contente pas d'un liseré : la teinte
    // envahit la carte, le trait s'epaissit, l'ombre porte plus loin. Elle
    // doit se reperer en balayant l'ecran, sans lire.
    final surface = isDark ? AppTheme.surfaceDark : Colors.white;
    final fillTop = pinned
        ? Color.lerp(surface, tint, isDark ? 0.34 : 0.20)!
        : Color.lerp(surface, tint, isDark ? 0.17 : 0.08)!;
    final fillBottom =
        pinned ? Color.lerp(surface, tint, isDark ? 0.14 : 0.06)! : surface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          transform: Matrix4.identity()..translate(0.0, _hover ? -3.0 : 0.0),
          padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [fillTop, fillBottom],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tint.withValues(
                  alpha: pinned ? (_hover ? 0.85 : 0.60) : (_hover ? 0.44 : 0.22)),
              width: pinned ? 1.8 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: tint.withValues(
                    alpha: pinned
                        ? (_hover ? 0.42 : 0.26)
                        : (_hover ? (isDark ? 0.30 : 0.20) : 0.10)),
                blurRadius: pinned ? (_hover ? 28 : 18) : (_hover ? 22 : 12),
                offset: Offset(0, _hover ? 9 : 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      size: pinned ? 30 : 26,
                      color: tint.withValues(alpha: pinned ? 0.95 : 0.6)),
                  if (pinned) ...[
                    const SizedBox(width: 8),
                    _PinnedBadge(tint: tint, isDark: isDark),
                  ],
                  const Spacer(),
                  // Les actions restent visibles en permanence. Cachees
                  // jusqu'au survol, elles etaient introuvables : il fallait
                  // ouvrir la citation pour epingler, et sur telephone le
                  // survol n'existe meme pas.
                  Opacity(
                    opacity: 1,
                    child: Row(
                      children: [
                        _PinButton(
                          pinned: pinned,
                          tint: tint,
                          isDark: isDark,
                          onTap: widget.onTogglePin,
                        ),
                        const SizedBox(width: 2),
                        FavoriteToggle(
                          isFavorite: note.isFavorite,
                          onChanged: (_) => widget.onToggleFavorite(),
                          size: 18,
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          onPressed: widget.onDelete,
                          icon: const Icon(Icons.delete_outline_rounded),
                          iconSize: 17,
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                              minWidth: 30, minHeight: 30),
                          padding: EdgeInsets.zero,
                          tooltip: 'Supprimer',
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                note.quote!.trim(),
                style: TextStyle(
                  fontSize: 16.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.2,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 2,
                    decoration: BoxDecoration(
                      color: tint.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      author.isEmpty ? _formatDate(note.createdAt) : author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color:
                            isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                      ),
                    ),
                  ),
                  // Une citation posee dans une chronique ecrite le dit : on
                  // sait ainsi qu'il y a un texte derriere la phrase.
                  if (note.content.trim().isNotEmpty)
                    Tooltip(
                      message: 'Extraite d’une chronique',
                      child: Icon(Icons.auto_stories_rounded,
                          size: 13,
                          color: (isDark
                                  ? AppTheme.textMutedDark
                                  : AppTheme.textMuted)
                              .withValues(alpha: 0.7)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// Marque « épinglée », posee a cote du guillemet.
class _PinnedBadge extends StatelessWidget {
  final Color tint;
  final bool isDark;

  const _PinnedBadge({required this.tint, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.30 : 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tint.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.push_pin_rounded, size: 11, color: tint),
          const SizedBox(width: 5),
          Text(
            'ÉPINGLÉE',
            style: TextStyle(
              fontSize: 8.5,
              height: 1.2,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.9,
              color: isDark ? Colors.white : Color.lerp(tint, Colors.black, 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'epingle : elle plante ou retire la phrase du haut de la liste.
class _PinButton extends StatefulWidget {
  final bool pinned;
  final Color tint;
  final bool isDark;
  final VoidCallback onTap;

  const _PinButton({
    required this.pinned,
    required this.tint,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends State<_PinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.pinned;
    return Tooltip(
      message: active ? 'Retirer l’épingle' : 'Épingler cette phrase',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: active || _hover
                  ? widget.tint.withValues(alpha: active ? 0.22 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            // L'epingle penche tant qu'elle n'est pas plantee : droite, elle
            // dit que la phrase est retenue.
            child: AnimatedRotation(
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              turns: active ? 0 : -0.1,
              child: Icon(
                active
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                size: 16,
                color: active
                    ? widget.tint
                    : (_hover
                        ? widget.tint
                        : (widget.isDark ? Colors.white38 : Colors.black26)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton d'ajout, dans l'en-tete sur desktop et dans l'ecran vide.
class _AddQuoteButton extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;
  final bool expanded;

  const _AddQuoteButton({
    required this.accent,
    required this.onTap,
    this.expanded = false,
  });

  @override
  State<_AddQuoteButton> createState() => _AddQuoteButtonState();
}

class _AddQuoteButtonState extends State<_AddQuoteButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 24 : 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accent, Colors.white, _hover ? 0.16 : 0.06)!,
                Color.lerp(accent, Colors.black, 0.22)!,
              ],
            ),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: _hover ? 0.44 : 0.26),
                blurRadius: _hover ? 18 : 11,
                offset: Offset(0, _hover ? 6 : 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_rounded, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              const Text(
                'Citation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
