import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import '../models/spark.dart';
import '../services/note_service.dart';
import '../widgets/swipeable_note_card.dart';
import '../utils/page_transitions.dart';
import '../theme/app_theme.dart';
import 'note_edit_screen.dart';
import 'note_view_screen.dart';
import '../widgets/user_avatar.dart';
import '../services/auth_service.dart';
import '../services/spark_service.dart';
import 'spark_edit_screen.dart';
import 'sparks_list_screen.dart';
import '../services/guidance_service.dart';
import 'dart:async';
import 'dart:math';
import 'main_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];
  int _sparkCount = 0;
  bool _isLoading = true;
  String _headerPrompt = '';
  Timer? _promptTimer;
  String _searchQuery = '';
  int _selectedFilter = 0;
  final _searchController = TextEditingController();
  final _filters = ['Toutes', 'Favoris', 'Images', 'Récentes'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _updateHeaderPrompt();
    // Changer le message toutes les 30 secondes
    _promptTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateHeaderPrompt();
    });
    _loadNotes();
  }

  void _updateHeaderPrompt() {
    setState(() {
      _headerPrompt = GuidanceService.instance.getTimeBasedWelcomeMessage();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _promptTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
  }

  void _applyFilters() {
    _filteredNotes = _notes.where((note) {
      final matchSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchFilter = true;
      if (_selectedFilter == 1) matchFilter = note.isFavorite;
      if (_selectedFilter == 2) matchFilter = note.imagePaths.isNotEmpty;
      if (_selectedFilter == 3)
        matchFilter = DateTime.now().difference(note.modifiedAt).inDays < 7;

      return matchSearch && matchFilter;
    }).toList()
      ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      _notes = await NoteService.instance.getAllNotes();
      _sparkCount = SparkService.instance.getAllSparks().length;
      _applyFilters();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote(Note note) async {
    await NoteService.instance.saveNote(note);
    _loadNotes();
  }

  Future<void> _deleteNote(Note note) async {
    await NoteService.instance.deleteNote(note.id);
    _loadNotes();
  }

  void _toggleFavorite(Note note) {
    note.isFavorite = !note.isFavorite;
    _saveNote(note);
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
            onDelete: () {
              Navigator.pop(context);
              _deleteNote(note);
            },
            onToggleFavorite: () => _toggleFavorite(note),
          ),
        ));
  }

  void _editNote(Note note) {
    Navigator.push(
        context,
        PageTransitions.scaleTransition(
          NoteEditScreen(note: note, onSave: _saveNote),
        ));
  }

  void _createNote() {
    Navigator.push(
        context,
        PageTransitions.scaleTransition(
          NoteEditScreen(
            note: Note(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              title: '',
              content: '',
              createdAt: DateTime.now(),
              modifiedAt: DateTime.now(),
              imagePaths: [],
              color: Colors.white,
              isFavorite: false,
            ),
            onSave: _saveNote,
          ),
        ));
  }

  void _createSpark() {
    Navigator.push(context, PageTransitions.scaleTransition(
      SparkEditScreen(
        onSave: (spark) async {
          await SparkService.instance.saveSpark(spark);
          // Optionnel: rafraichir si on affiche les sparks ici
        },
      ),
    ));
  }

  void _showNewChoice() {
    final allSparks = SparkService.instance.getAllSparks();
    final randomSpark = allSparks.isNotEmpty
        ? allSparks[Random().nextInt(allSparks.length)]
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24, top: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (randomSpark != null) ...[
              _buildInspirationSection(randomSpark),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 24),
            ],
            const Text(
              'Ou partir d\'une page blanche',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.auto_stories_rounded,
                    title: 'Chronique',
                    subtitle: 'Une chronique complète',
                    color: AppTheme.skyBlue,
                    onTap: () {
                      Navigator.pop(context);
                      _createNote();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Étincelle',
                    subtitle: 'Une idée rapide',
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _createSpark();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspirationSection(Spark spark) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppTheme.skyBlue, size: 20),
            const SizedBox(width: 8),
            Text(
              'INSPIRATION DU MOMENT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppTheme.skyBlue,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
            _developSpark(spark);
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withOpacity(isDark ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.skyBlue.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        GuidanceService.instance.getDevelopSparkPrompt(spark.title),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                          height: 1.4,
                        ),
                      ),
                      if (spark.description != null && spark.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          spark.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.skyBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _developSpark(Spark spark) {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(
        NoteEditScreen(
          note: Note(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: spark.title,
            content: spark.description ?? '',
            createdAt: DateTime.now(),
            modifiedAt: DateTime.now(),
            imagePaths: spark.imagePath != null ? [spark.imagePath!] : [],
            color: Colors.white,
            isFavorite: false,
          ),
          onSave: _saveNote,
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.1),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
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
      body: CustomScrollView(
        slivers: [
          // Card bleue avec header, search et filtres (scrollable)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.skyBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Safe area padding
                  SizedBox(height: statusBarHeight + 8),
                  // Header
                  _buildHeader(isDark),
                  // Search
                  _buildSearch(isDark),
                  // Filters
                  _buildFilters(isDark),
                ],
              ),
            ),
          ),
          // Content (notes)
          _buildContent(isDark),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader(bool isDark) {
    final favCount = _notes.where((n) => n.isFavorite).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo de l'app
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: UserAvatar(
              displayName: AuthService.instance.userName ?? '?',
              userId: AuthService.instance.userId,
              radius: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Texte
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mes Chroniques',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _headerPrompt,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.1,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.2),
                        offset: const Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildStatWhite('${_notes.length}', 'notes'),
                    if (favCount > 0) _buildStatWhite('$favCount', '❤️'),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SparksListScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(isDark ? 0.15 : 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.7),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                size: 20, color: isDark ? Colors.white : AppTheme.skyBlue),
                            const SizedBox(width: 8),
                            Text(
                              _sparkCount > 0
                                  ? 'Voir étincelles ($_sparkCount)'
                                  : 'Voir étincelles',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppTheme.skyBlue,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatWhite(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9))),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
              fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Rechercher une note...',
            hintStyle: TextStyle(
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted),
            prefixIcon: Icon(Icons.search_rounded,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMuted,
                        size: 20),
                    onPressed: _searchController.clear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_filters.length, (i) {
            final selected = _selectedFilter == i;
            return Padding(
              padding: EdgeInsets.only(right: i < _filters.length - 1 ? 10 : 0),
              child: GestureDetector(
                onTap: () => setState(() {
                  _selectedFilter = i;
                  _applyFilters();
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        selected ? Colors.white : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _filters[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.skyBlue : Colors.white,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    if (_isLoading) {
      return SliverFillRemaining(
        child:
            Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
      );
    }

    if (_filteredNotes.isEmpty) {
      return SliverFillRemaining(child: _buildEmpty(isDark));
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        itemBuilder: (_, i) => SwipeableNoteCard(
          note: _filteredNotes[i],
          onTap: () => _openNote(_filteredNotes[i]),
          onFavoriteToggle: () => _toggleFavorite(_filteredNotes[i]),
          onEdit: () => _editNote(_filteredNotes[i]),
          onDelete: () => _deleteNote(_filteredNotes[i]),
        ),
        childCount: _filteredNotes.length,
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final isFiltered = _searchQuery.isNotEmpty || _selectedFilter != 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFiltered ? Icons.search_off_rounded : Icons.note_add_rounded,
              size: 56,
              color: AppTheme.skyBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isFiltered ? 'Aucun résultat' : 'Aucune note',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Essayez d\'autres critères'
                : 'Créez votre première note',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
          if (!isFiltered) ...[
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _showNewChoice,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Nouvelle'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showNewChoice,
      backgroundColor: AppTheme.skyBlue,
      foregroundColor: Colors.white,
      elevation: 6,
      icon: const Icon(Icons.add_rounded),
      label:
          const Text('Nouvelle', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
