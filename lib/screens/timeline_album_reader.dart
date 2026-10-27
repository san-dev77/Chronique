import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'note_view_screen.dart';
import '../services/note_service.dart';

/// Album reader immersif — affiche les notes comme un livre
/// avec animation page flip (3D perspective rotation).
class TimelineAlbumReader extends StatefulWidget {
  final String title;
  final List<Note> notes;
  final Color accentColor;
  final IconData icon;

  const TimelineAlbumReader({
    super.key,
    required this.title,
    required this.notes,
    required this.accentColor,
    required this.icon,
  });

  @override
  State<TimelineAlbumReader> createState() => _TimelineAlbumReaderState();
}

class _TimelineAlbumReaderState extends State<TimelineAlbumReader> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          // Un lecteur se feuillette au clavier : c'est le geste attendu des
          // qu'on est assis devant un ecran.
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final k = event.logicalKey;
          if (k == LogicalKeyboardKey.arrowRight ||
              k == LogicalKeyboardKey.pageDown) {
            _pageController.nextPage(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic);
          } else if (k == LogicalKeyboardKey.arrowLeft ||
              k == LogicalKeyboardKey.pageUp) {
            _pageController.previousPage(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic);
          } else if (k == LogicalKeyboardKey.escape) {
            Navigator.of(context).maybePop();
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: SafeArea(
          child: Column(
            children: [
              ContentBounds(maxWidth: 900, child: _buildTopBar(isDark)),
              ContentBounds(maxWidth: 900, child: _buildProgressBar(isDark)),
              Expanded(
                child: widget.notes.isEmpty
                    ? _buildEmpty(isDark)
                    : _buildBookPages(isDark),
              ),
              ContentBounds(maxWidth: 900, child: _buildBottomNav(isDark)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 8),
          Icon(widget.icon, color: widget.accentColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_currentPage + 1}/${widget.notes.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: widget.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(bool isDark) {
    if (widget.notes.isEmpty) return const SizedBox(height: 12);
    final progress = (widget.notes.length > 1)
        ? _currentPage / (widget.notes.length - 1)
        : 1.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(widget.accentColor),
          minHeight: 3,
        ),
      ),
    );
  }

  Widget _buildBookPages(bool isDark) {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.notes.length,
      onPageChanged: (index) => setState(() => _currentPage = index),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildPage(widget.notes[index], index, isDark);
      },
    );
  }

  Widget _buildPage(Note note, int index, bool isDark) {
    final hasAura = NoteMood.hasGlow(note.mood);
    final auraColor = hasAura
        ? NoteMood.getEffectiveColor(note.mood, note.moodColor)
        : widget.accentColor;
    final moodData = NoteMood.fromKey(note.mood);
    final hasImage = note.imagePaths.isNotEmpty;

    return GestureDetector(
      onTap: () => _openNote(note),
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          double value = 0;
          if (_pageController.position.haveDimensions) {
            value = index - (_pageController.page ?? 0);
            value = (value * 0.04).clamp(-1.0, 1.0);
          }
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(value * pi / 4),
            child: child,
          );
        },
        // Colonne de lecture bornee : la page occupait toute la largeur, soit
        // des lignes de texte de 1 800 px sur un ecran desktop.
        child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
          margin: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: auraColor.withOpacity(isDark ? 0.3 : 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: auraColor.withOpacity(isDark ? 0.2 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              if (hasAura)
                BoxShadow(
                  color: auraColor.withOpacity(isDark ? 0.15 : 0.06),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image de la note (si disponible)
                  if (hasImage && File(note.imagePaths.first).existsSync())
                    Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, c) {
                            final dpr =
                                MediaQuery.devicePixelRatioOf(context);
                            return Image.file(
                              File(note.imagePaths.first),
                              height: 230,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              cacheWidth: c.maxWidth.isFinite && c.maxWidth > 0
                                  ? (c.maxWidth * dpr).round()
                                  : null,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            );
                          },
                        ),
                        // Gradient overlay pour le texte
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: 60,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  (isDark ? AppTheme.surfaceDark : Colors.white)
                                      .withOpacity(0.9),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête : date + aura
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: auraColor
                                    .withOpacity(isDark ? 0.25 : 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 12, color: auraColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    _formatDate(note.createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: auraColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (moodData != null && hasAura)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: auraColor
                                      .withOpacity(isDark ? 0.4 : 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(moodData.icon,
                                        size: 12, color: auraColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      moodData.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: auraColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Numéro de page
                        Text(
                          'PAGE ${index + 1}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.5,
                            color: (isDark
                                    ? AppTheme.textMutedDark
                                    : AppTheme.textMuted)
                                .withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Titre
                        if (note.title.isNotEmpty) ...[
                          Text(
                            note.title,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? AppTheme.textLight
                                  : AppTheme.textDark,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            height: 3,
                            width: 50,
                            decoration: BoxDecoration(
                              color: auraColor.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Contenu
                        if (note.content.isNotEmpty)
                          Text(
                            note.content,
                            style: TextStyle(
                              fontSize: 15,
                              color: (isDark
                                      ? AppTheme.textLight
                                      : AppTheme.textDark)
                                  .withOpacity(0.8),
                              height: 1.8,
                            ),
                            maxLines: 18,
                            overflow: TextOverflow.fade,
                          ),

                        if (note.title.isEmpty && note.content.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Column(
                                children: [
                                  Icon(Icons.edit_note_rounded,
                                      size: 40,
                                      color: (isDark
                                              ? AppTheme.textMutedDark
                                              : AppTheme.textMuted)
                                          .withOpacity(0.3)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Page vide',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: (isDark
                                              ? AppTheme.textMutedDark
                                              : AppTheme.textMuted)
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        const SizedBox(height: 24),

                        Center(
                          child: TextButton.icon(
                            onPressed: () => _openNote(note),
                            icon: Icon(Icons.auto_stories_rounded,
                                size: 16, color: auraColor),
                            label: Text(
                              'Lire la chronique complète',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: auraColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    if (widget.notes.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavButton(
            icon: Icons.chevron_left_rounded,
            enabled: _currentPage > 0,
            onTap: () => _pageController.previousPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            ),
            isDark: isDark,
          ),
          // Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              min(widget.notes.length, 7),
              (i) {
                final start = max(0, _currentPage - 3);
                final dotIndex = start + i;
                if (dotIndex >= widget.notes.length)
                  return const SizedBox.shrink();
                final isActive = dotIndex == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 18 : 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.accentColor
                        : (isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              },
            ),
          ),
          _buildNavButton(
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < widget.notes.length - 1,
            onTap: () => _pageController.nextPage(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            ),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  void _openNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteViewScreen(
          note: note,
          onEdit: () => Navigator.pop(context),
          onDelete: () {
            NoteService.instance.deleteNote(note.id);
            Navigator.pop(context);
          },
          onToggleFavorite: () {
            note.isFavorite = !note.isFavorite;
            // Marquer un favori ne doit pas rajeunir la note.
            NoteService.instance.saveNote(note, touch: false);
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    const months = [
      '', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jui', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    return '${days[date.weekday - 1]} ${date.day} ${months[date.month]}';
  }

  Widget _buildNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return _ReaderNavButton(
      icon: icon,
      enabled: enabled,
      onTap: onTap,
      isDark: isDark,
      accent: widget.accentColor,
      label: icon == Icons.chevron_left_rounded ? 'Précédent' : 'Suivant',
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Text(
        'Aucune chronique dans cet album',
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
        ),
      ),
    );
  }
}

/// Bouton de feuilletage. L'ancien etait un GestureDetector nu : aucune
/// reaction au survol ni au clic, et pas de curseur.
class _ReaderNavButton extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool isDark;
  final Color accent;
  final String label;

  const _ReaderNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.isDark,
    required this.accent,
    required this.label,
  });

  @override
  State<_ReaderNavButton> createState() => _ReaderNavButtonState();
}

class _ReaderNavButtonState extends State<_ReaderNavButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    final accent = widget.accent;

    return Tooltip(
      message: widget.icon == Icons.chevron_left_rounded
          ? '${widget.label}  ·  ←'
          : '${widget.label}  ·  →',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: on ? widget.onTap : null,
          onTapDown: on ? (_) => setState(() => _down = true) : null,
          onTapUp: on ? (_) => setState(() => _down = false) : null,
          onTapCancel: () => setState(() => _down = false),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: on ? 1 : 0.28,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 110),
              scale: _down ? 0.93 : 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                decoration: BoxDecoration(
                  color: on && _hover
                      ? accent
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.045)),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: on && _hover
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.42),
                            blurRadius: 16,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  widget.icon,
                  size: 19,
                  color: on && _hover
                      ? Colors.white
                      : (widget.isDark
                          ? AppTheme.textMutedDark
                          : AppTheme.textMuted),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
