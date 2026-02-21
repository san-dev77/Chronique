import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../services/note_service.dart';
import '../theme/app_theme.dart';
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
    _scrollController = ScrollController();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadNotes();
  }

  @override
  void dispose() {
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

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: albums.isEmpty
                  ? _buildEmptyState(isDark)
                  : _buildTimeline(albums, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          Icon(Icons.menu_book_rounded, color: AppTheme.skyBlue, size: 28),
          const SizedBox(width: 12),
          Text(
            'Albums',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_allNotes.length} chroniques',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.skyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
      List<MapEntry<String, List<Note>>> albums, bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final entry = albums[index];
        final isLeft = index.isEven;

        return AnimatedBuilder(
          animation: _entryController,
          builder: (context, child) {
            final delay = (index * 0.12).clamp(0.0, 0.8);
            final progress = Curves.easeOutCubic.transform(
              ((_entryController.value - delay) / (1.0 - delay)).clamp(0.0, 1.0),
            );
            return Transform.translate(
              offset: Offset(isLeft ? -30 * (1 - progress) : 30 * (1 - progress), 0),
              child: Opacity(opacity: progress, child: child),
            );
          },
          child: _buildTimelineItem(entry.key, entry.value, index, isDark),
        );
      },
    );
  }

  Widget _buildTimelineItem(
      String key, List<Note> notes, int index, bool isDark) {
    final isLeft = index.isEven;
    final label = _monthLabel(key);

    // Trouver l'image de couverture (première note avec image)
    String? coverImage;
    for (final note in notes) {
      if (note.imagePaths.isNotEmpty) {
        coverImage = note.imagePaths.first;
        break;
      }
    }

    // Aura dominante
    Color albumColor = AppTheme.skyBlue;
    int auraCount = 0;
    for (final note in notes) {
      if (NoteMood.hasGlow(note.mood)) {
        albumColor = NoteMood.getEffectiveColor(note.mood, note.moodColor);
        auraCount++;
      }
    }
    if (auraCount == 0) albumColor = AppTheme.skyBlue;

    final sortedNotes = List<Note>.from(notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Côté gauche
          if (!isLeft) Expanded(child: Container()),
          if (isLeft)
            Expanded(
              child: _buildAlbumCard(
                  label, sortedNotes, coverImage, albumColor, isDark),
            ),

          // Ligne de timeline au centre
          SizedBox(
            width: 40,
            child: Column(
              children: [
                // Point de la timeline
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: albumColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: albumColor.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                // Ligne verticale
                Expanded(
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          albumColor.withOpacity(0.6),
                          albumColor.withOpacity(0.1),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Côté droit
          if (isLeft) Expanded(child: Container()),
          if (!isLeft)
            Expanded(
              child: _buildAlbumCard(
                  label, sortedNotes, coverImage, albumColor, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(String label, List<Note> notes, String? coverImage,
      Color albumColor, bool isDark) {
    return GestureDetector(
      onTap: () => _openAlbum(context, label, notes, albumColor),
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: albumColor.withOpacity(isDark ? 0.3 : 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: albumColor.withOpacity(isDark ? 0.2 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image de couverture
            if (coverImage != null && File(coverImage).existsSync())
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
                child: Image.file(
                  File(coverImage),
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Titre du mois
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.textLight : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Nombre de notes
                  Row(
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          size: 12, color: albumColor),
                      const SizedBox(width: 4),
                      Text(
                        '${notes.length} chronique${notes.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMutedDark
                              : AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Aperçu des titres
                  ...notes.take(2).map((note) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          note.title.isNotEmpty ? note.title : 'Sans titre',
                          style: TextStyle(
                            fontSize: 10,
                            color: (isDark
                                    ? AppTheme.textMutedDark
                                    : AppTheme.textMuted)
                                .withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
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
