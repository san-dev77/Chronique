import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import '../models/note.dart';
import '../services/note_service.dart';
import '../theme/app_theme.dart';
import '../utils/page_transitions.dart';
import 'note_view_screen.dart';
import 'note_edit_screen.dart';
import '../widgets/user_avatar.dart';
import '../services/auth_service.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<MemoryCollection> _collections = [];
  bool _isLoading = true;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);

    try {
      final allNotes = await NoteService.instance.getAllNotes();
      _collections = _generateMemoryCollections(allNotes);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<MemoryCollection> _generateMemoryCollections(List<Note> notes) {
    if (notes.isEmpty) return [];

    final collections = <MemoryCollection>[];
    final now = DateTime.now();

    final notesByMonth = <String, List<Note>>{};
    for (final note in notes) {
      final key = '${note.createdAt.year}-${note.createdAt.month}';
      notesByMonth.putIfAbsent(key, () => []).add(note);
    }

    // 1. Souvenirs d'il y a 1 an
    final oneYearAgo = DateTime(now.year - 1, now.month);
    final oneYearKey = '${oneYearAgo.year}-${oneYearAgo.month}';
    if (notesByMonth.containsKey(oneYearKey)) {
      final yearNotes = notesByMonth[oneYearKey]!;
      final selected = _selectRandomNotes(yearNotes, 5);
      if (selected.isNotEmpty) {
        collections.add(MemoryCollection(
          title: 'Il y a 1 an',
          subtitle: '${_getMonthName(oneYearAgo.month)} ${oneYearAgo.year}',
          notes: selected,
          icon: Icons.calendar_today_rounded,
          color: AppTheme.skyBlue,
        ));
      }
    }

    // 2. Mois dernier
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthKey = '${lastMonth.year}-${lastMonth.month}';
    if (notesByMonth.containsKey(lastMonthKey)) {
      final monthNotes = notesByMonth[lastMonthKey]!;
      final selected = _selectRandomNotes(monthNotes, 5);
      if (selected.isNotEmpty) {
        collections.add(MemoryCollection(
          title: 'Le mois dernier',
          subtitle: _getMonthName(lastMonth.month),
          notes: selected,
          icon: Icons.history_rounded,
          color: AppTheme.skyBlue,
        ));
      }
    }

    // 3. Redécouvrez
    final oldNotes =
        notes.where((n) => now.difference(n.createdAt).inDays > 30).toList();
    if (oldNotes.isNotEmpty) {
      final randomSelection = _selectRandomNotes(oldNotes, 6);
      if (randomSelection.isNotEmpty) {
        collections.add(MemoryCollection(
          title: 'Redécouvrez',
          subtitle: 'Stories oubliées',
          notes: randomSelection,
          icon: Icons.auto_awesome_rounded,
          color: AppTheme.skyBlue,
        ));
      }
    }

    // 4. Souvenirs visuels
    final notesWithImages =
        notes.where((n) => n.imagePaths.isNotEmpty).toList();
    if (notesWithImages.isNotEmpty) {
      final selected = _selectRandomNotes(notesWithImages, 5);
      if (selected.isNotEmpty) {
        collections.add(MemoryCollection(
          title: 'Souvenirs visuels',
          subtitle: 'Vos photos',
          notes: selected,
          icon: Icons.photo_library_rounded,
          color: AppTheme.skyBlue,
        ));
      }
    }

    // 5. Favoris
    final favoriteNotes = notes.where((n) => n.isFavorite).toList();
    if (favoriteNotes.isNotEmpty) {
      final selected = _selectRandomNotes(favoriteNotes, 5);
      if (selected.isNotEmpty) {
        collections.add(MemoryCollection(
          title: 'Coups de cœur',
          subtitle: 'Favoris',
          notes: selected,
          icon: Icons.favorite_rounded,
          color: AppTheme.skyBlue,
        ));
      }
    }

    // 6. Moments intenses (notes les plus longues)
    final longNotes = List<Note>.from(notes);
    longNotes.sort((a, b) {
      final aLength = a.title.length + a.content.length;
      final bLength = b.title.length + b.content.length;
      return bLength.compareTo(aLength);
    });
    final topLongNotes = longNotes
        .take(10)
        .where((n) => (n.title.length + n.content.length) > 100)
        .toList();
    if (topLongNotes.length >= 3) {
      final selected = _selectRandomNotes(topLongNotes, 5);
      collections.add(MemoryCollection(
        title: 'Vos moments intenses',
        subtitle: 'Stories les plus riches',
        notes: selected,
        icon: Icons.local_fire_department_rounded,
        color: AppTheme.skyBlue,
      ));
    }

    // 7. Mois aléatoire
    final pastMonths = notesByMonth.entries
        .where((e) => e.key != '${now.year}-${now.month}')
        .toList();
    if (pastMonths.isNotEmpty) {
      pastMonths.shuffle(_random);
      final randomMonth = pastMonths.first;
      final parts = randomMonth.key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final selected = _selectRandomNotes(randomMonth.value, 5);
      if (selected.isNotEmpty) {
        collections.add(MemoryCollection(
          title: 'En ${_getMonthName(month)} $year',
          subtitle: 'Un mois au hasard',
          notes: selected,
          icon: Icons.event_note_rounded,
          color: AppTheme.skyBlue,
        ));
      }
    }

    // 8. Moment Surprise (Totalement aléatoire)
    if (notes.length > 5) {
      final randomNotes = _selectRandomNotes(notes, 4);
      collections.add(MemoryCollection(
        title: 'Moment Surprise',
        subtitle: 'Une note au hasard pour vous',
        notes: randomNotes,
        icon: Icons.auto_awesome_rounded,
        color: AppTheme.skyBlue,
      ));
    }

    // 9. Par couleur
    final colorsInNotes = notes.map((n) => n.color).toSet().toList();
    if (colorsInNotes.isNotEmpty) {
      final randomColor = colorsInNotes[_random.nextInt(colorsInNotes.length)];
      final filteredByColor = notes.where((n) => n.color == randomColor).toList();
      if (filteredByColor.length >= 2) {
        collections.add(MemoryCollection(
          title: 'Thème de Couleur',
          subtitle: 'Stories coordonnées',
          notes: _selectRandomNotes(filteredByColor, 5),
          icon: Icons.palette_rounded,
          color: randomColor,
        ));
      }
    }

    // Mélanger un peu l'ordre des collections pour la variété (sauf la première si elle existe)
    if (collections.length > 3) {
      final first = collections.removeAt(0);
      collections.shuffle(_random);
      collections.insert(0, first);
    }

    return collections;
  }

  List<Note> _selectRandomNotes(List<Note> notes, int count) {
    if (notes.isEmpty) return [];
    if (notes.length <= count) return List.from(notes)..shuffle(_random);
    final shuffled = List<Note>.from(notes)..shuffle(_random);
    return shuffled.take(count).toList();
  }

  String _getMonthName(int month) {
    const months = [
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre'
    ];
    return months[month];
  }

  void _openNote(Note note) {
    Navigator.push(
        context,
        PageTransitions.heroTransition(
          NoteViewScreen(
            note: note,
            onEdit: () {
              Navigator.pop(context);
              _editNote(note);
            },
            onDelete: () async {
              Navigator.pop(context);
              await NoteService.instance.deleteNote(note.id);
              _loadMemories();
            },
            onToggleFavorite: () async {
              await NoteService.instance
                  .saveNote(note.copyWith(isFavorite: !note.isFavorite));
              _loadMemories();
            },
          ),
        ));
  }

  void _editNote(Note note) {
    Navigator.push(
        context,
        PageTransitions.scaleTransition(
          NoteEditScreen(
            note: note,
            onSave: (n) async {
              await NoteService.instance.saveNote(n);
              _loadMemories();
            },
          ),
        ));
  }

  /// Ouvre le diaporama plein écran
  void _openSlideshow(MemoryCollection collection) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _SlideshowScreen(
          collection: collection,
          onNoteTap: _openNote,
        ),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(opacity: anim, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.skyBlue,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: RefreshIndicator(
        onRefresh: _loadMemories,
        color: AppTheme.skyBlue,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(statusBarHeight, isDark)),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.skyBlue)),
              )
            else if (_collections.isEmpty)
              SliverFillRemaining(child: _buildEmpty(isDark))
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _MemoryCollectionWidget(
                    collection: _collections[index],
                    isDark: isDark,
                    onNoteTap: _openNote,
                    onPlayTap: () => _openSlideshow(_collections[index]),
                  ),
                  childCount: _collections.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double statusBarHeight, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, statusBarHeight + 20, 24, 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.skyBlue, AppTheme.skyBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.skyBlue.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Souvenirs',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.textLight : AppTheme.textDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    UserAvatar(
                      displayName: AuthService.instance.userName ?? '?',
                      userId: AuthService.instance.userId,
                      radius: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Redécouvrez vos stories',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loadMemories,
            icon: Icon(Icons.refresh_rounded,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted),
            tooltip: 'Nouvelles suggestions',
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.skyBlue.withOpacity(0.1),
                    AppTheme.skyBlue.withOpacity(0.1)
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  size: 56, color: AppTheme.skyBlue),
            ),
            const SizedBox(height: 24),
            Text(
              'Pas encore de souvenirs',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Créez des stories pour générer des souvenirs',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget pour une collection avec PageView et indicateurs
class _MemoryCollectionWidget extends StatefulWidget {
  final MemoryCollection collection;
  final bool isDark;
  final Function(Note) onNoteTap;
  final VoidCallback onPlayTap;

  const _MemoryCollectionWidget({
    required this.collection,
    required this.isDark,
    required this.onNoteTap,
    required this.onPlayTap,
  });

  @override
  State<_MemoryCollectionWidget> createState() =>
      _MemoryCollectionWidgetState();
}

class _MemoryCollectionWidgetState extends State<_MemoryCollectionWidget> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec bouton Play
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.collection.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.collection.icon,
                      color: widget.collection.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.collection.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: widget.isDark
                              ? AppTheme.textLight
                              : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        widget.collection.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.collection.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bouton Diaporama
                GestureDetector(
                  onTap: widget.onPlayTap,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.collection.color,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.collection.color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('Diapo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // PageView des notes
          SizedBox(
            height: 200,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: widget.collection.notes.length,
              itemBuilder: (context, index) {
                return _buildMemoryCard(widget.collection.notes[index], index);
              },
            ),
          ),

          const SizedBox(height: 12),

          // Indicateurs de pagination + hint swipe
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Flèche gauche
              Icon(
                Icons.chevron_left_rounded,
                size: 20,
                color: _currentPage > 0
                    ? (widget.isDark
                        ? AppTheme.textMutedDark
                        : AppTheme.textMuted)
                    : Colors.transparent,
              ),
              const SizedBox(width: 8),
              // Dots
              ...List.generate(widget.collection.notes.length, (i) {
                final isActive = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? widget.collection.color
                        : widget.collection.color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Flèche droite
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _currentPage < widget.collection.notes.length - 1
                    ? (widget.isDark
                        ? AppTheme.textMutedDark
                        : AppTheme.textMuted)
                    : Colors.transparent,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(Note note, int index) {
    final hasImage = note.imagePaths.isNotEmpty;
    final textColor =
        note.color.computeLuminance() > 0.5 ? AppTheme.textDark : Colors.white;

    return GestureDetector(
      onTap: () => widget.onNoteTap(note),
      child: AnimatedBuilder(
        animation: _pageController,
        builder: (context, child) {
          double value = 1.0;
          if (_pageController.position.haveDimensions) {
            value = (_pageController.page! - index).abs();
            value = (1 - (value * 0.15)).clamp(0.85, 1.0);
          }
          return Center(
            child: Transform.scale(
              scale: value,
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: note.color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.collection.color.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                if (hasImage)
                  Positioned.fill(
                    child: Image.file(
                      File(note.imagePaths.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                if (hasImage)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7)
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (note.isFavorite)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.skyBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.favorite,
                                  color: Colors.white, size: 14),
                            ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${index + 1}/${widget.collection.notes.length}',
                              style: TextStyle(
                                fontSize: 11,
                                color: hasImage
                                    ? Colors.white
                                    : textColor.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (note.title.isNotEmpty)
                        Text(
                          note.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: hasImage ? Colors.white : textColor,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (note.content.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          note.content,
                          style: TextStyle(
                            fontSize: 14,
                            color: hasImage
                                ? Colors.white.withOpacity(0.85)
                                : textColor.withOpacity(0.7),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran Diaporama plein écran avec auto-play
class _SlideshowScreen extends StatefulWidget {
  final MemoryCollection collection;
  final Function(Note) onNoteTap;

  const _SlideshowScreen({
    required this.collection,
    required this.onNoteTap,
  });

  @override
  State<_SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<_SlideshowScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  bool _isPlaying = true;
  Timer? _autoPlayTimer;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _progressController.forward(from: 0);
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_isPlaying && mounted) {
        if (_currentPage < widget.collection.notes.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Retour au début
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
        _progressController.forward(from: 0);
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _startAutoPlay();
      } else {
        _pauseAutoPlay();
      }
    });
  }

  void _pauseAutoPlay() {
    _autoPlayTimer?.cancel();
    _progressController.stop();
  }

  void _resumeAutoPlay() {
    if (_isPlaying && mounted) {
      _startAutoPlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.collection.notes[_currentPage];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView plein écran avec Hold to Pause
          GestureDetector(
            onLongPressStart: (_) => _pauseAutoPlay(),
            onLongPressEnd: (_) => _resumeAutoPlay(),
            onLongPressCancel: () => _resumeAutoPlay(),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
                if (_isPlaying) {
                  _progressController.forward(from: 0);
                }
              },
              itemCount: widget.collection.notes.length,
              itemBuilder: (context, index) =>
                  _buildSlide(widget.collection.notes[index]),
            ),
          ),

          // Barre de progression en haut
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              children: List.generate(widget.collection.notes.length, (i) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: i == _currentPage
                        ? AnimatedBuilder(
                            animation: _progressController,
                            builder: (_, __) => FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: _progressController.value,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          )
                        : i < _currentPage
                            ? Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              )
                            : null,
                  ),
                );
              }),
            ),
          ),

          // Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Bouton fermer
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
                const Spacer(),
                // Info collection
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.collection.color.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.collection.icon,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        widget.collection.title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Bouton play/pause
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Footer avec infos note
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, 40, 24, MediaQuery.of(context).padding.bottom + 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (note.title.isNotEmpty)
                    Text(
                      note.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      note.content,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.5,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Date
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule,
                                size: 14, color: Colors.white70),
                            const SizedBox(width: 6),
                            Text(
                              _formatDate(note.createdAt),
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Bouton ouvrir
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          widget.onNoteTap(note);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Voir',
                                  style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.black87, size: 18),
                            ],
                          ),
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
    );
  }

  Widget _buildSlide(Note note) {
    final hasImage = note.imagePaths.isNotEmpty;

    return Container(
      color: hasImage ? Colors.black : note.color,
      child: hasImage
          ? Image.file(
              File(note.imagePaths.first),
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                color: note.color,
                child: const Center(
                  child: Icon(Icons.image_not_supported,
                      color: Colors.white54, size: 64),
                ),
              ),
            )
          : null,
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Juin',
      'Juil',
      'Août',
      'Sep',
      'Oct',
      'Nov',
      'Déc'
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

/// Modèle pour une collection de souvenirs
class MemoryCollection {
  final String title;
  final String subtitle;
  final List<Note> notes;
  final IconData icon;
  final Color color;

  MemoryCollection({
    required this.title,
    required this.subtitle,
    required this.notes,
    required this.icon,
    required this.color,
  });
}
