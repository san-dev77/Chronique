import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../widgets/note_card.dart';
import '../utils/page_transitions.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/screen_header.dart';
import 'note_edit_screen.dart';
import 'note_view_screen.dart';
import '../widgets/user_avatar.dart';
import '../services/auth_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Note> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // L'ecran reste vivant dans l'IndexedStack : il doit se remettre a jour
    // quand les chroniques changent ailleurs. Sans cette ecoute, un ecran
    // ouvert avant la fin de la synchronisation restait vide pour toujours —
    // c'est ce qui faisait croire que les souvenirs et les albums ne
    // chargeaient pas.
    NoteService.instance.revision.addListener(_onDataChanged);
    _load();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  @override
  void dispose() {
    NoteService.instance.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await NoteService.instance.waitReady();
      final all = NoteService.instance.getAllNotes();
      _favorites = all.where((n) => n.isFavorite).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save(Note note) async {
    await NoteService.instance.saveNote(note);
    _load();
  }

  Future<void> _delete(Note note) async {
    await NoteService.instance.deleteNote(note.id);
    _load();
  }

  void _toggleFav(Note note) =>
      _save(note.copyWith(isFavorite: !note.isFavorite));

  void _open(Note note) {
    Navigator.push(
        context,
        PageTransitions.heroTransition(
          NoteViewScreen(
            note: note,
            onEdit: () {
              Navigator.pop(context);
              _edit(note);
            },
            onDelete: () {
              Navigator.pop(context);
              _delete(note);
            },
            onToggleFavorite: () => _toggleFav(note),
          ),
        ));
  }

  void _edit(Note note) {
    Navigator.push(
        context,
        PageTransitions.scaleTransition(
          NoteEditScreen(note: note, onSave: _save),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.skyBlue,
      statusBarIconBrightness: Brightness.light,
    ));

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              screenHeaderSliver(
                width: width,
                pinnedHeight: 116,
                header: ScreenHeader(
                  width: width,
                  icon: Icons.favorite_rounded,
                  title: 'Favoris',
                  subtitle: _favorites.isEmpty
                      ? 'Vos chroniques préférées apparaîtront ici'
                      : '${_favorites.length} chronique${_favorites.length > 1 ? 's' : ''} mise${_favorites.length > 1 ? 's' : ''} de côté',
                  accent: const Color(0xFFE05252),
                ),
              ),
              _buildContent(isDark, width),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.skyBlue.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
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
                      'Favoris',
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${_favorites.length} chroniques',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.skyBlue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, double width) {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
      );
    }

    if (_favorites.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppTheme.skyBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_outline_rounded,
                    size: 56, color: AppTheme.skyBlue),
              ),
              const SizedBox(height: 24),
              Text(
                'Aucun favori',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajoutez des chroniques à vos favoris',
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

    final insets = Responsive.contentInsets(width);
    final wide = Responsive.useSidebar(width);
    final gutter = Responsive.gutter(width);

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
          insets.left, wide ? 22 : 16, insets.right, wide ? 40 : 100),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: Responsive.noteColumns(width - insets.horizontal),
        mainAxisSpacing: gutter,
        crossAxisSpacing: gutter,
        itemBuilder: (_, i) => NoteCard(
          note: _favorites[i],
          onTap: () => _open(_favorites[i]),
          onFavoriteToggle: () => _toggleFav(_favorites[i]),
        ),
        childCount: _favorites.length,
      ),
    );
  }
}
