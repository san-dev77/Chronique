import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../services/note_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/screen_header.dart';
import 'timeline_album_reader.dart';

/// Écran Timeline — affiche une courbe chronologique avec les albums par mois.
/// Chaque album pop depuis la courbe avec une animation.
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen>
    with SingleTickerProviderStateMixin {
  List<Note> _allNotes = [];
  late ScrollController _scrollController;
  late AnimationController _entryController;

  @override
  void initState() {
    super.initState();
    // L'ecran reste vivant dans l'IndexedStack : il doit se remettre a jour
    // quand les chroniques changent ailleurs. Sans cette ecoute, un ecran
    // ouvert avant la fin de la synchronisation restait vide pour toujours —
    // c'est ce qui faisait croire que les souvenirs et les albums ne
    // chargeaient pas.
    NoteService.instance.revision.addListener(_onDataChanged);
    _scrollController = ScrollController();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadNotes();
  }

  void _onDataChanged() {
    if (mounted) _loadNotes();
  }

  @override
  void dispose() {
    NoteService.instance.revision.removeListener(_onDataChanged);
    _scrollController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _loadNotes() {
    final notes = NoteService.instance.getAllNotes();
    setState(() => _allNotes = notes);
    _entryController.forward();
  }

  /// Groupe les notes par mois et trie par date desc
  List<MapEntry<String, List<Note>>> _getAlbums() {
    final Map<String, List<Note>> groups = {};
    for (final note in _allNotes) {
      final key =
          '${note.createdAt.year}-${note.createdAt.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(note);
    }
    final sorted = groups.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted;
  }

  String _monthLabel(String key) {
    final parts = key.split('-');
    final year = parts[0];
    final month = int.parse(parts[1]);
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[month]} $year';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ));

    final albums = _getAlbums();

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        body: SafeArea(
          child: Column(
            children: [
              ScreenHeader(
                width: width,
                icon: Icons.menu_book_rounded,
                title: 'Albums',
                subtitle: albums.isEmpty
                    ? 'Vos chroniques se regrouperont ici par période'
                    : '${albums.length} album${albums.length > 1 ? 's' : ''}  ·  ${_allNotes.length} chroniques',
              ),
              Expanded(
                child: albums.isEmpty
                    ? _buildEmptyState(isDark)
                    : ContentBounds(child: _buildTimeline(albums, isDark)),
              ),
            ],
          ),
        ),
      );
    });
  }

  /// Albums groupes par annee.
  ///
  /// L'ecran presentait une frise en zigzag : les cartes alternaient de part
  /// et d'autre d'une ligne centrale. Sur desktop, cela laissait la moitie de
  /// la largeur vide a chaque rangee. Les mois sont desormais en grille sous
  /// leur annee, ce qui remplit l'espace et se lit d'un coup d'oeil.
  Widget _buildTimeline(
      List<MapEntry<String, List<Note>>> albums, bool isDark) {
    final byYear = <String, List<MapEntry<String, List<Note>>>>{};
    for (final entry in albums) {
      final year = entry.key.split('-').first;
      byYear.putIfAbsent(year, () => []).add(entry);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final insets = Responsive.contentInsets(width);
      final avail = width - insets.horizontal;
      final columns = avail >= 1180
          ? 4
          : avail >= 860
              ? 3
              : avail >= 560
                  ? 2
                  : 1;
      const gap = 16.0;
      final cardW = (avail - gap * (columns - 1)) / columns;

      return ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.fromLTRB(insets.left, 20, insets.right, 100),
        itemCount: years.length,
        itemBuilder: (context, yi) {
          final year = years[yi];
          final months = byYear[year]!;
          final total =
              months.fold<int>(0, (sum, e) => sum + e.value.length);

          return AnimatedBuilder(
            animation: _entryController,
            builder: (context, child) {
              final delay = (yi * 0.14).clamp(0.0, 0.7);
              final t = Curves.easeOutCubic.transform(
                ((_entryController.value - delay) / (1.0 - delay))
                    .clamp(0.0, 1.0),
              );
              return Transform.translate(
                offset: Offset(0, 22 * (1 - t)),
                child: Opacity(opacity: t, child: child),
              );
            },
            child: Padding(
              padding: EdgeInsets.only(bottom: yi == years.length - 1 ? 0 : 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre d'annee : un repere fort, avec le filet qui rappelle
                  // la frise d'origine.
                  Row(
                    children: [
                      Text(
                        year,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: isDark
                              ? AppTheme.textLight
                              : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$total chronique${total > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.skyBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: months.map((entry) {
                      return SizedBox(
                        width: cardW,
                        child: _albumTile(entry.key, entry.value, isDark),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _albumTile(String key, List<Note> notes, bool isDark) {
    String? cover;
    for (final note in notes) {
      if (note.imagePaths.isNotEmpty) {
        cover = note.imagePaths.first;
        break;
      }
    }

    // Teinte de l'album : celle de l'aura dominante du mois.
    Color color = AppTheme.skyBlue;
    for (final note in notes) {
      if (NoteMood.hasGlow(note.mood)) {
        color = NoteMood.getEffectiveColor(note.mood, note.moodColor);
        break;
      }
    }

    final sorted = List<Note>.from(notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return _AlbumTile(
      label: _monthLabel(key).split(' ').first,
      cover: cover,
      count: notes.length,
      photoCount: notes.where((n) => n.imagePaths.isNotEmpty).length,
      color: color,
      isDark: isDark,
      onTap: () => _openAlbum(context, _monthLabel(key), sorted, color),
    );
  }

  void _openAlbum(
      BuildContext context, String title, List<Note> notes, Color color) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) {
          return TimelineAlbumReader(
            title: title,
            notes: notes,
            accentColor: color,
            icon: Icons.calendar_month_rounded,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Animation d'ouverture de livre — scale + rotation + fade
          final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return AnimatedBuilder(
            animation: curve,
            builder: (context, _) {
              return Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY((1 - curve.value) * -pi / 6),
                child: Opacity(
                  opacity: curve.value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: (isDark ? AppTheme.textMutedDark : AppTheme.textMuted)
                .withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune chronique',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vos albums apparaîtront ici\nlorsque vous écrirez des chroniques',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: (isDark ? AppTheme.textMutedDark : AppTheme.textMuted)
                  .withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vignette d'un mois.
class _AlbumTile extends StatefulWidget {
  final String label;
  final String? cover;
  final int count;
  final int photoCount;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _AlbumTile({
    required this.label,
    required this.cover,
    required this.count,
    required this.photoCount,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<_AlbumTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final hasCover =
        widget.cover != null && File(widget.cover!).existsSync();
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..translate(0.0, _hover ? -5.0 : 0.0),
          height: 182,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: _hover ? 0.55 : 0.16),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? color.withValues(alpha: 0.30)
                    : Colors.black.withValues(
                        alpha: widget.isDark ? 0.28 : 0.05),
                blurRadius: _hover ? 26 : 14,
                offset: Offset(0, _hover ? 12 : 5),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover)
                LayoutBuilder(
                  builder: (context, c) => AnimatedScale(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    scale: _hover ? 1.07 : 1,
                    child: Image.file(
                      File(widget.cover!),
                      fit: BoxFit.cover,
                      cacheWidth: c.maxWidth.isFinite && c.maxWidth > 0
                          ? (c.maxWidth * dpr).round()
                          : null,
                      errorBuilder: (_, __, ___) =>
                          Container(color: color.withValues(alpha: 0.2)),
                    ),
                  ),
                )
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: widget.isDark ? 0.32 : 0.18),
                        color.withValues(alpha: widget.isDark ? 0.10 : 0.05),
                      ],
                    ),
                  ),
                ),

              // Voile : le mois reste lisible sur n'importe quelle photo.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: hasCover ? 0.15 : 0),
                        Colors.black.withValues(alpha: hasCover ? 0.72 : 0),
                      ],
                      stops: const [0.35, 1],
                    ),
                  ),
                ),
              ),

              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.15,
                child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (widget.photoCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_rounded,
                                    size: 11, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.photoCount}',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 160),
                          opacity: _hover ? 1 : 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.55),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            height: 1.15,
                            color: hasCover
                                ? Colors.white
                                : (widget.isDark
                                    ? AppTheme.textLight
                                    : AppTheme.textDark),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.count} chronique${widget.count > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                            color: hasCover
                                ? Colors.white.withValues(alpha: 0.8)
                                : (widget.isDark
                                    ? AppTheme.textMutedDark
                                    : AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
