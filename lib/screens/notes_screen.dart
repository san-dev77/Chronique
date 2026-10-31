import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import '../models/spark.dart';
import '../services/cloud_sync_service.dart';
import '../services/note_service.dart';
import '../widgets/swipeable_note_card.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive.dart';
import '../widgets/save_flash.dart';
import '../widgets/screen_header.dart';
import '../widgets/app_chrome.dart';
import '../widgets/create_chooser.dart';
import 'quote_edit_screen.dart';
import 'quotes_screen.dart';
import '../theme/app_theme.dart';
import 'main_screen.dart' show MainScreenActions;
import 'note_edit_screen.dart';
import 'note_compose_flow.dart';
import 'note_view_screen.dart';
import '../widgets/user_avatar.dart';
import '../services/auth_service.dart';
import '../services/spark_service.dart';
import 'spark_edit_screen.dart';
import 'sparks_list_screen.dart';
import '../services/guidance_service.dart';
import '../utils/french_dates.dart';
import '../widgets/search_sheet.dart';
import '../widgets/motion.dart';
import 'dart:async';
import 'dart:math';

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
  String _searchQuery = '';
  Timer? _searchDebounce;
  final _searchFocus = FocusNode();
  List<int> _filterCounts = const [0, 0, 0, 0, 0];
  int _selectedFilter = 0;
  final _searchController = TextEditingController();
  final _filters = ['Toutes', 'Favoris', 'Images', 'Citations', 'Récentes'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // L'ecran reste vivant dans l'IndexedStack : il doit donc se remettre a
    // jour quand une note change ailleurs (Ctrl+N, sync cloud, autre onglet).
    NoteService.instance.revision.addListener(_onNotesChanged);
    // Ctrl+F est capte au niveau de MainScreen (au-dessus dans l'arbre de
    // focus) : cet ecran s'y enregistre pour recevoir l'ordre.
    NotesScreenActions.focusSearch = _focusSearch;
    _loadNotes();
  }

  void _focusSearch() {
    if (!mounted) return;
    if (Responsive.isWide(context)) {
      _searchFocus.requestFocus();
    } else {
      _showSearchModal();
    }
  }

  void _onNotesChanged() {
    if (!mounted) return;
    setState(() {
      _notes = NoteService.instance.getAllNotes();
      _sparkCount = SparkService.instance.getAllSparks().length;
      _applyFilters();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _searchFocus.dispose();
    NoteService.instance.revision.removeListener(_onNotesChanged);
    if (NotesScreenActions.focusSearch == _focusSearch) {
      NotesScreenActions.focusSearch = null;
    }
    super.dispose();
  }

  void _onSearchChanged() {
    // Sans anti-rebond, chaque frappe refiltrait et retriait toute la liste.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text;
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    _filterCounts = _computeFilterCounts();
    _filteredNotes = _notes.where((note) {
      final matchSearch = _searchQuery.isEmpty ||
          note.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          note.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (note.quote?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);

      bool matchFilter = true;
      if (_selectedFilter == 1) matchFilter = note.isFavorite;
      if (_selectedFilter == 2) matchFilter = note.imagePaths.isNotEmpty;
      if (_selectedFilter == 3)
        matchFilter = note.quote != null && note.quote!.isNotEmpty;
      if (_selectedFilter == 4) {
        matchFilter = DateTime.now().difference(note.createdAt).inDays < 7;
      }

      return matchSearch && matchFilter;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _loadNotes() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _notes = NoteService.instance.getAllNotes();
      _sparkCount = SparkService.instance.getAllSparks().length;
      _applyFilters();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote(Note note) async {
    // Le rafraichissement passe par NoteService.revision : pas de rechargement
    // manuel, donc pas de clignotement de l'indicateur de chargement.
    await NoteService.instance.saveNote(note);
  }

  Future<void> _deleteNote(Note note) async {
    await NoteService.instance.deleteNote(note.id);
    if (mounted) await showDeleteFlash(context);
  }

  void _toggleFavorite(Note note) {
    note.isFavorite = !note.isFavorite;
    // Marquer un favori n'est pas une modification du contenu : la note ne
    // doit ni changer de date ni sauter en tete de liste.
    NoteService.instance.saveNote(note, touch: false);
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
    // Parcours guide : image, cadrage, aura, puis l'ecriture.
    Navigator.push(
        context,
        PageTransitions.scaleTransition(
          NoteComposeFlow(onSave: _saveNote),
        ));
  }

  void _createSpark() {
    Navigator.push(context, PageTransitions.scaleTransition(
      SparkEditScreen(
        onSave: (spark) async {
          await SparkService.instance.saveSpark(spark);
          // Optionnel: rafraichir si on affiche les sparks ici
          if (mounted) _loadNotes();
        },
      ),
    ));
  }

  void _showSearchModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildSearchModal(),
    );
  }

  Widget _buildSearchModal() {
    // La feuille vit dans son propre fichier : 315 lignes de mise en page
    // melees au reste de l'ecran rendaient l'ensemble illisible, et c'est
    // dans ce fouillis que les bordures grey.shade300 ignorant le theme
    // sombre avaient pu passer inapercues.
    //
    // StatefulBuilder : la feuille est posee par showModalBottomSheet, donc
    // hors de l'arbre de cet ecran. Sans cela, taper dans le champ ne
    // redessinait rien et la liste restait figee.
    return StatefulBuilder(
      builder: (context, setSheetState) {
        void refresh() {
          // Le filtrage se fait a la frappe, sans attendre l'anti-rebond de
          // l'ecran : ici la liste est sous les yeux, un retard de 220 ms se
          // verrait.
          _searchQuery = _searchController.text;
          _applyFilters();
          if (mounted) setState(() {});
          setSheetState(() {});
        }

        return SearchSheetHost(
          controller: _searchController,
          onQueryChanged: refresh,
          builder: (query) => SearchSheet(
            controller: _searchController,
            query: query,
            filters: _filters,
            filterCounts: _filterCounts,
            selectedFilter: _selectedFilter,
            onFilterChanged: (i) {
              _selectedFilter = i;
              _applyFilters();
              refresh();
            },
            results: _filteredNotes,
            onOpenNote: (note) {
              Navigator.pop(context);
              _openNote(note);
            },
            sparkCount: _sparkCount,
            quoteCount: _notes
                .where((n) => n.quote != null && n.quote!.trim().isNotEmpty)
                .length,
            favoriteCount: _notes.where((n) => n.isFavorite).length,
            onOpenSparks: () {
              Navigator.pop(context);
              _openSparks();
            },
            onOpenQuotes: () {
              Navigator.pop(context);
              _openQuotes();
            },
            onShowFavorites: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _selectedFilter = 1;
                  _applyFilters();
                });
              }
            },
          ),
        );
      },
    );
  }

  List<int> _computeFilterCounts() {
    return [
      _notes.length, // Toutes
      _notes.where((n) => n.isFavorite).length, // Favoris
      _notes.where((n) => n.imagePaths.isNotEmpty).length, // Images
      _notes
          .where((n) => n.quote != null && n.quote!.isNotEmpty)
          .length, // Citations
      _notes
          .where((n) => DateTime.now().difference(n.modifiedAt).inDays < 7)
          .length, // Récentes
    ];
  }

  Future<void> _showNewChoice() async {
    final allSparks = SparkService.instance.getAllSparks();
    final randomSpark = allSparks.isNotEmpty
        ? allSparks[Random().nextInt(allSparks.length)]
        : null;

    final kind = await showCreateChooser(
      context,
      // Une etincelle tiree au hasard, offerte comme point de depart : c'est
      // a cela qu'elles servent.
      inspiration:
          randomSpark == null ? null : _buildInspirationSection(randomSpark),
    );
    if (kind == null || !mounted) return;

    switch (kind) {
      case CreateKind.note:
        _createNote();
      case CreateKind.quote:
        _createQuote();
      case CreateKind.spark:
        _createSpark();
    }
  }

  void _createQuote() {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(
        QuoteEditScreen(
          onSave: (note, {bool isNew = false}) async {
            await NoteService.instance.saveNote(note, isNew: isNew);
            if (mounted) _onNotesChanged();
          },
        ),
      ),
    );
  }

  void _openSparks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SparksListScreen()),
    );
  }

  void _openQuotes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuotesScreen()),
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
              color: AppTheme.skyBlue.withValues(alpha: isDark ? 0.15 : 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.skyBlue.withValues(alpha: 0.3),
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
                        GuidanceService.instance
                            .getDevelopSparkPrompt(spark.title),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                          height: 1.4,
                        ),
                      ),
                      if (spark.description != null &&
                          spark.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          spark.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                isDark ? Colors.white60 : Colors.grey.shade600,
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
                        color: AppTheme.skyBlue.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
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

  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Sans objet sur desktop, et inutile de le rejouer a chaque build.
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: AppTheme.skyBlue,
        statusBarIconBrightness: Brightness.light,
      ));
    }

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final wide = Responsive.useSidebar(width);

      return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: CustomScrollView(
        slivers: [
          // En-tete : bandeau colore sur mobile, barre sobre sur desktop.
          if (wide)
            // En-tete epinglee : elle reste visible pendant le defilement.
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedHeader(
                height: 146,
                // `overlaps` dit si le contenu passe sous l'en-tete : c'est
                // le signal qui lui fait prendre un relief, et seulement
                // alors. Une ombre permanente serait du decor.
                builder: (overlaps) =>
                    _buildDesktopHeader(isDark, width, overlaps),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  // Un aplat d'accent restait plat ; le degrade donne au
                  // bandeau une epaisseur, et l'ombre le detache du fond.
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(AppTheme.skyBlue, Colors.white, 0.10)!,
                      AppTheme.skyBlue,
                      Color.lerp(AppTheme.skyBlue, Colors.black, 0.18)!,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.skyBlue.withValues(alpha: 0.34),
                      blurRadius: 22,
                      offset: const Offset(0, 9),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(height: statusBarHeight + 8),
                    _buildSimpleHeader(isDark),
                  ],
                ),
              ),
            ),
          // Content (notes)
          _buildContent(isDark, width),
        ],
      ),
      // Sur desktop, la creation vit dans la barre laterale : un bouton
      // flottant en bas a droite n'est pas la ou l'oeil le cherche.
      // L'ecran vide porte deja son propre bouton « Nouvelle » : en garder
      // un second flottant juste en dessous faisait doublon.
      floatingActionButton:
          wide || (_filteredNotes.isEmpty && !_isLoading) ? null : _buildFAB(),
      );
    });
  }

  /// En-tete desktop : une barre basse, une vraie zone de recherche et les
  /// filtres a plat. Le bandeau bleu pleine largeur du mobile mangeait 200 px
  /// de hauteur pour afficher un titre.
  Widget _buildDesktopHeader(bool isDark, double width, bool overlaps) {
    final insets = Responsive.contentInsets(width);
    final accent = AppTheme.skyBlue;
    final surface = isDark ? AppTheme.surfaceDark : Colors.white;
    final favCount = _notes.where((n) => n.isFavorite).length;

    // Hauteur fixe + texte : l'echelle de police du systeme peut faire
    // deborder. On la borne ici, sans toucher aux surfaces de lecture ou
    // elle compte vraiment (note ouverte, editeur).
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          // L'accent affleure a peine sous la barre laterale, assez pour que
          // les deux surfaces se repondent sans qu'on voie une jointure.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.55, 1],
            colors: [
              Color.lerp(surface, accent, isDark ? 0.06 : 0.028)!,
              surface,
              surface,
            ],
          ),
          boxShadow: overlaps
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.34)
                        : accent.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding:
                  EdgeInsets.fromLTRB(insets.left, 20, insets.right, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 46,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Mes Chroniques',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.8,
                              color: isDark ? Colors.white : AppTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 24),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxWidth: 340, minWidth: 210),
                          child: _SearchField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            accent: accent,
                            isDark: isDark,
                            hasText: _searchQuery.isNotEmpty,
                            onClear: () {
                              _searchController.clear();
                              if (mounted) {
                                setState(() {
                                  _searchQuery = '';
                                  _applyFilters();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        RefreshAction(
                          onRefresh: () async {
                            try {
                              await CloudSyncService.instance.syncAll();
                            } catch (_) {
                              // Hors ligne : on rafraichit depuis le local.
                            }
                            if (mounted) _onNotesChanged();
                          },
                          tooltip: 'Synchroniser et actualiser',
                        ),
                        const SizedBox(width: 12),
                        _ProfileAvatar(
                          name: AuthService.instance.userName,
                          userId: AuthService.instance.userId,
                          accent: accent,
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Les filtres a gauche, le decompte a droite : la ligne
                  // porte le choix d'un cote et l'etat de l'autre.
                  SizedBox(
                    height: 42,
                    child: Row(
                      children: [
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: SegmentedFilters(
                              segments: [
                                for (var i = 0; i < _filters.length; i++)
                                  FilterSegment(_filters[i], _filterCounts[i]),
                              ],
                              selected: _selectedFilter,
                              accent: accent,
                              isDark: isDark,
                              onSelect: (i) {
                                if (!mounted) return;
                                setState(() {
                                  _selectedFilter = i;
                                  _applyFilters();
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            child: Row(
                              children: [
                                _StatPill(
                                  icon: Icons.auto_stories_rounded,
                                  value: '${_notes.length}',
                                  label: _notes.length > 1
                                      ? 'chroniques'
                                      : 'chronique',
                                  accent: accent,
                                  isDark: isDark,
                                ),
                                if (favCount > 0) ...[
                                  const SizedBox(width: 8),
                                  _StatPill(
                                    icon: Icons.favorite_rounded,
                                    value: '$favCount',
                                    label: 'favoris',
                                    accent: const Color(0xFFE05252),
                                    isDark: isDark,
                                  ),
                                ],
                                if (_sparkCount > 0) ...[
                                  const SizedBox(width: 8),
                                  _StatPill(
                                    icon: Icons.bolt_rounded,
                                    value: '$_sparkCount',
                                    label: 'étincelles',
                                    accent: accent,
                                    isDark: isDark,
                                  ),
                                ],
                                const _PendingImages(onBanner: false),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // La limite basse se devine aux extremites et s'affirme au
            // centre, la ou le contenu commence.
            Positioned(
              left: insets.left,
              right: insets.right,
              bottom: 0,
              child: FadingDivider(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : accent.withValues(alpha: 0.16),
                fade: 0.06,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleHeader(bool isDark) {
    final favCount = _notes.where((n) => n.isFavorite).length;
    final quotesCount =
        _notes.where((n) => n.quote != null && n.quote!.isNotEmpty).length;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 18, 22),
        child: Row(
          // Aligne en haut : la colonne de droite a gagne une rangee de
          // boutons, et un avatar centre se retrouvait a flotter a cote des
          // compteurs au lieu de repondre au titre.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // L'avatar, cercle clair sur le bandeau : le point de depart du
            // regard, et l'acces au compte.
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: GestureDetector(
              onTap: () => MainScreenActions.goToTab
                  ?.call(MainScreenActions.settingsTab),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: UserAvatar(
                  displayName: AuthService.instance.userName ?? '?',
                  userId: AuthService.instance.userId,
                  radius: 22,
                ),
              ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mes Chroniques',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 7),
                  // Des icones plutot que des emoji : un coeur dessine se
                  // pose a la bonne taille et prend la couleur du bandeau,
                  // ce qu'un caractere emoji ne sait pas faire.
                  //
                  // Les Etincelles et les Citations n'ont pas leur place dans
                  // la barre du bas, deja pleine. Elles s'ouvrent d'ici : un
                  // bouton sous le titre, la ou l'oeil passe en premier.
                  Row(
                    children: [
                      _buildStatBadge(
                          Icons.auto_stories_rounded, '${_notes.length}'),
                      if (favCount > 0) ...[
                        const SizedBox(width: 7),
                        _buildStatBadge(
                            Icons.favorite_rounded, '$favCount'),
                      ],
                      const _PendingImages(onBanner: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Le Wrap qui precedait faisait descendre « Citations »
                  // d'une ligne des que les compteurs grossissaient : les
                  // deux boutons se retrouvaient l'un sous l'autre, ce qui
                  // n'etait ni voulu ni lisible. Deux Expanded partagent la
                  // largeur a parts egales — ils restent cote a cote quelle
                  // que soit la largeur de l'ecran, et le libelle s'abrege
                  // plutot que de deborder.
                  Row(
                    children: [
                      Expanded(
                        child: _BannerAccess(
                          icon: Icons.bolt_rounded,
                          label: 'Étincelles',
                          count: _sparkCount,
                          onTap: _openSparks,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _BannerAccess(
                          icon: Icons.format_quote_rounded,
                          label: 'Citations',
                          count: quotesCount,
                          onTap: _openQuotes,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _MobileHeaderButton(
              icon: Icons.search_rounded,
              tooltip: 'Rechercher',
              onTap: _showSearchModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, double width) {
    if (_isLoading) {
      return SliverFillRemaining(
        child:
            Center(child: CircularProgressIndicator(color: AppTheme.skyBlue)),
      );
    }

    if (_filteredNotes.isEmpty) {
      return SliverFillRemaining(child: _buildEmpty(isDark));
    }

    // Colonnes selon la largeur reellement disponible, et contenu centre
    // au-dela de 1360 px plutot qu'etire sur toute la fenetre.
    final insets = Responsive.contentInsets(width);
    final gutter = Responsive.gutter(width);

    final wide = Responsive.useSidebar(width);
    final columns = Responsive.noteColumns(width - insets.horizontal);
    final groupes = groupeParMois(_filteredNotes, (n) => n.createdAt);

    // Une section par mois, et chaque section porte sa propre maconnerie,
    // non defilante et construite d'un bloc.
    //
    // Ce detail est tout le sujet. Une grille en maconnerie paresseuse ne
    // connait pas sa hauteur avant d'avoir construit ses cartes : elle
    // l'estime. Quinze de ces grilles a la suite, c'etaient quinze
    // estimations qui se corrigeaient au fil du defilement, et une
    // estimation qui retrecit rappelle la position vers le haut — 1050 px
    // de recul mesures, soit un retour au mois courant sans fin.
    //
    // En construisant chaque mois d'un bloc, son etendue est exacte des le
    // depart : plus rien a corriger. La paresse se deplace au niveau de la
    // SECTION — un mois hors champ n'est pas construit du tout — et un mois
    // compte au plus une vingtaine de chroniques, donc la poussee memoire
    // reste bornee.
    //
    // test/scroll_stabilite_test.dart chiffre les sept dispositions
    // envisagees. Ne pas revenir a une suite de slivers paresseux.
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        insets.left,
        // L'en-tete est epinglee : sans respiration, la premiere rangee de
        // cartes vient la toucher des le premier defilement.
        wide ? 22 : 0,
        insets.right,
        wide ? 40 : 100,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, g) {
            final groupe = groupes[g];
            // Rang global, pour que la cascade d'apparition traverse les
            // mois sans repartir de zero a chaque bandeau.
            final base =
                groupes.take(g).fold<int>(0, (n, gr) => n + gr.length);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MonthHeading(
                  label: libelleDuMois(groupe.first.createdAt),
                  count: groupe.length,
                  isDark: isDark,
                  // Le premier bandeau touche le haut de la zone : il n'a
                  // pas besoin de l'ecart qui separe les mois suivants.
                  topGap: g == 0 ? 0 : gutter + 14,
                ),
                MasonryGridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: gutter,
                  crossAxisSpacing: gutter,
                  itemCount: groupe.length,
                  itemBuilder: (_, i) =>
                      _buildEnhancedNoteCard(groupe[i], rang: base + i),
                ),
              ],
            );
          },
          childCount: groupes.length,
        ),
      ),
    );
  }

  /// Chroniques dont l'apparition a deja ete jouee.
  ///
  /// La grille recycle ses cartes : sans cette memoire, chaque retour en
  /// arriere rejouait l'entree et la liste clignotait au defilement. On
  /// retient donc les identifiants, pas les rangs — l'ordre peut changer.
  final Set<String> _apparues = {};

  Widget _buildEnhancedNoteCard(Note note, {int rang = 0}) {
    final premiere = _apparues.add(note.id);

    return Reveal(
      // La cle porte l'identifiant : Flutter ne recycle pas l'etat de
      // l'apparition d'une chronique vers une autre.
      key: ValueKey('reveal-${note.id}'),
      index: rang,
      animate: premiere,
      child: _carte(note),
    );
  }

  Widget _carte(Note note) {
    return SwipeableNoteCard(
      // Cle stable : sans elle, un changement d'ordre detruit l'etat des
      // cartes — et l'animation du cœur disparaissait avant d'etre vue.
      key: ValueKey(note.id),
      note: note,
      onTap: () => _openNote(note),
      onFavoriteToggle: () => _toggleFavorite(note),
      onEdit: () => _editNote(note),
      onDelete: () => _deleteNote(note),
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
              color: AppTheme.skyBlue.withValues(alpha: 0.1),
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
            isFiltered ? 'Aucun résultat' : 'Aucune chronique',
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
                : 'Votre première chronique vous attend',
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
      heroTag: 'fab_notes',
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

/// Point d'entree pour les raccourcis clavier declares plus haut dans l'arbre.
class NotesScreenActions {
  NotesScreenActions._();
  static VoidCallback? focusSearch;
}

/// Puce de filtre de l'en-tete desktop, avec etat de survol.
/// Bouton du bandeau mobile : translucide, et qui s'eclaire a la pression.
class _MobileHeaderButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MobileHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_MobileHeaderButton> createState() => _MobileHeaderButtonState();
}

class _MobileHeaderButtonState extends State<_MobileHeaderButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: _down ? 0.34 : 0.20),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Acces direct depuis le bandeau : une icone, un mot, un compteur.
///
/// La barre du bas tient six entrees, pas huit. Plutot que de tout empiler
/// dans un menu, les deux formes qui ne sont pas des chroniques s'ouvrent
/// depuis l'ecran ou l'on passe de toute facon.
class _BannerAccess extends StatefulWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _BannerAccess({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  @override
  State<_BannerAccess> createState() => _BannerAccessState();
}

class _BannerAccessState extends State<_BannerAccess> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        // Resserre pour que les deux boutons tiennent sur une ligne : a deux
        // lignes, le bandeau mangeait un quart de l'ecran.
        height: 33,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: _down ? 0.34 : 0.20),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        // Le bouton remplit desormais la moitie du bandeau : son contenu se
        // centre, et le libelle cede la place au compteur plutot que de
        // pousser le tout hors de l'ecran.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            if (widget.count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${widget.count}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Signale les photos encore en route.
///
/// A la premiere connexion sur un appareil, le texte des chroniques arrive en
/// quelques secondes et les photos en quelques minutes. Sans rien pour le
/// dire, l'application donne l'impression d'avoir perdu les images — c'est
/// exactement la conclusion qu'on en tire, et elle est fausse.
class _PendingImages extends StatelessWidget {
  final bool onBanner;

  const _PendingImages({required this.onBanner});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<int>(
      valueListenable: CloudSyncService.instance.pendingImages,
      builder: (context, pending, _) {
        if (pending == 0) return const SizedBox.shrink();

        final color = onBanner
            ? Colors.white
            : (isDark ? AppTheme.textMutedDark : AppTheme.textMuted);

        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Container(
            height: onBanner ? 26 : 30,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              color: onBanner
                  ? Colors.white.withValues(alpha: 0.18)
                  : AppTheme.skyBlue.withValues(alpha: isDark ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(onBanner ? 9 : 10),
              border: Border.all(
                color: onBanner
                    ? Colors.white.withValues(alpha: 0.16)
                    : AppTheme.skyBlue.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 11,
                  height: 11,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: onBanner ? Colors.white : AppTheme.skyBlue,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  onBanner ? '$pending' : '$pending photo${pending > 1 ? 's' : ''} en route',
                  style: TextStyle(
                    fontSize: onBanner ? 12 : 11.5,
                    height: 1.1,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compteur de l'en-tete : une icone, un nombre, un mot.
///
/// La chaine « 12 chroniques · 3 favoris · 5 etincelles » demandait a etre
/// lue. Trois pastilles se reconnaissent a leur icone, sans lecture.
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  final bool isDark;

  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.1,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// En-tete de hauteur fixe qui reste en place pendant le defilement.
class _PinnedHeader extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget Function(bool overlaps) builder;

  const _PinnedHeader({required this.height, required this.builder});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return SizedBox.expand(child: builder(overlaps));
  }

  @override
  bool shouldRebuild(_PinnedHeader old) => true;
}

/// Champ de recherche de l'en-tete desktop.
///
/// Le focus se voit : liseré d'accent, halo doux et raccourci qui s'efface
/// des qu'on commence a taper.
class _SearchField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color accent;
  final bool isDark;
  final bool hasText;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.accent,
    required this.isDark,
    required this.hasText,
    required this.onClear,
  });

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  bool _focused = false;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = widget.accent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        // Au repos, le champ est un creux dans la surface : pas de liseré,
        // juste un fond un peu plus sombre. Il ne prend de la couleur et du
        // relief qu'une fois qu'on s'y installe.
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: _focused ? 0.10 : 0.05)
              : (_focused
                  ? Colors.white
                  : Colors.black.withValues(alpha: _hover ? 0.045 : 0.032)),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: _focused
                ? accent
                : (_hover
                    ? accent.withValues(alpha: 0.28)
                    : Colors.transparent),
            width: _focused ? 1.6 : 1,
          ),
          boxShadow: _focused
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.20),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              child: Icon(
                Icons.search_rounded,
                size: 19,
                color: _focused
                    ? accent
                    : (isDark ? Colors.white54 : Colors.grey.shade500),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Rechercher une chronique',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ),
            ),
            if (widget.hasText)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: widget.onClear,
                  child: Icon(Icons.close_rounded,
                      size: 17,
                      color: isDark ? Colors.white54 : Colors.grey.shade600),
                ),
              )
            else if (!_focused)
              KbdHint(label: 'Ctrl F', isDark: isDark),
          ],
        ),
      ),
    );
  }
}

/// Avatar de l'en-tete : anneau degrade, pastille de presence, et un leger
/// soulevement au survol.
class _ProfileAvatar extends StatefulWidget {
  final String? name;
  final String? userId;
  final Color accent;
  final bool isDark;

  const _ProfileAvatar({
    required this.name,
    required this.userId,
    required this.accent,
    required this.isDark,
  });

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.userId != null;
    final accent = widget.accent;

    return Tooltip(
      message: signedIn
          ? (widget.name ?? 'Mon compte')
          : 'Non connecté — mode hors ligne',
      waitDuration: const Duration(milliseconds: 350),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: () => MainScreenActions.goToTab
              ?.call(MainScreenActions.settingsTab),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            transform: Matrix4.identity()..translate(0.0, _hover ? -2.0 : 0.0),
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  Color.lerp(accent, Colors.white, 0.45)!,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _hover ? 0.42 : 0.22),
                  blurRadius: _hover ? 16 : 9,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isDark ? AppTheme.surfaceDark : Colors.white,
              ),
              child: Stack(
                children: [
                  UserAvatar(
                    displayName: widget.name ?? '?',
                    userId: widget.userId,
                    radius: 18,
                  ),
                  if (signedIn)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3E9E74),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.isDark
                                ? AppTheme.surfaceDark
                                : Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Intertitre d'un mois dans la grille des chroniques.
///
/// Discret par construction : un mois n'est pas un titre de section, c'est
/// un repere. Il se lit en passant, sans concurrencer les cartes — d'ou le
/// corps petit, la graisse moderee et le filet qui s'eteint a droite.
class _MonthHeading extends StatelessWidget {
  final String label;
  final int count;
  final bool isDark;
  final double topGap;

  const _MonthHeading({
    required this.label,
    required this.count,
    required this.isDark,
    required this.topGap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? AppTheme.textMutedDark : AppTheme.textMuted;

    // Un repere, pas un titre de section : il se lit en passant et ne
    // concurrence pas les chroniques. D'ou le corps petit et le filet qui
    // s'eteint plutot qu'un trait franc d'un bord a l'autre, qui aurait
    // dessine une boite autour de chaque mois.
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 14),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.1,
              color: isDark ? Colors.white70 : AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.1,
              color: ink.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: FadingDivider(
              color: ink.withValues(alpha: isDark ? 0.22 : 0.18),
              fade: 0.04,
            ),
          ),
        ],
      ),
    );
  }
}
