import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math';
import 'dart:async';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../services/memory_periods.dart';
import '../services/note_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../utils/responsive.dart';
import '../widgets/screen_header.dart';
import '../utils/page_transitions.dart';
import 'note_view_screen.dart';
import 'note_edit_screen.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key});

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  List<MemoryCollection> _collections = [];
  bool _isLoading = true;

  /// Palette harmonisee. L'ecran utilisait douze couleurs vives sans rapport
  /// entre elles ni avec l'app — un arc-en-ciel sur fond bleu nuit.
  static const List<Color> _palette = [
    Color(0xFF5B8DBE),
    Color(0xFF7C6BD6),
    Color(0xFF3F9E8C),
    Color(0xFFC97B4A),
    Color(0xFFC25E7A),
    Color(0xFF4E9FE3),
  ];

  /// Incremente a chaque rafraichissement manuel : c'est le seul moment ou le
  /// tirage change.
  int _salt = 0;

  late Random _random;

  /// Graine du jour.
  ///
  /// Avant, `Random()` sans graine retirait tout a chaque ouverture de
  /// l'onglet : les souvenirs changeaient sous les yeux, et l'ordre des
  /// collections aussi. Un souvenir qui se redistribue a chaque regard n'en
  /// est plus un. Le tirage est desormais stable toute la journee, et se
  /// renouvelle demain — ou tout de suite si on demande un rafraichissement.
  int get _daySeed {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day + _salt * 7919;
  }

  @override
  void initState() {
    super.initState();
    // L'ecran reste vivant dans l'IndexedStack : il doit se remettre a jour
    // quand les chroniques changent ailleurs. Sans cette ecoute, un ecran
    // ouvert avant la fin de la synchronisation restait vide pour toujours —
    // c'est ce qui faisait croire que les souvenirs et les albums ne
    // chargeaient pas.
    NoteService.instance.revision.addListener(_onDataChanged);
    _loadMemories();
  }

  void _onDataChanged() {
    if (mounted) _loadMemories();
  }

  @override
  void dispose() {
    NoteService.instance.revision.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> _loadMemories() async {
    setState(() => _isLoading = true);

    try {
      _random = Random(_daySeed);
      final allNotes = NoteService.instance.getAllNotes();
      _collections = _generateMemoryCollections(allNotes);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Rafraichissement demande par l'utilisateur : nouveau tirage.
  Future<void> _reshuffle() async {
    _salt++;
    await _loadMemories();
  }

  List<MemoryCollection> _generateMemoryCollections(List<Note> notes) {
    if (notes.isEmpty) return [];

    final collections = <MemoryCollection>[];
    final now = DateTime.now();

    // Une note ne doit apparaitre que dans une seule collection. Sans cela,
    // la meme chronique se retrouvait dans « Souvenirs visuels », « Coups de
    // cœur », « Moments intenses » et « Auras intenses » : l'ecran repetait
    // les memes notes sous quatre etiquettes.
    final used = <String>{};

    List<Note> pick(List<Note> pool, int count) {
      final fresh = pool.where((n) => !used.contains(n.id)).toList();
      final chosen = _selectRandomNotes(fresh, count);
      used.addAll(chosen.map((n) => n.id));
      return chosen;
    }

    void add(String title, String subtitle, List<Note> chosen, IconData icon,
        {int minimum = 2, Color? color}) {
      if (chosen.length < minimum) return;
      collections.add(MemoryCollection(
        title: title,
        subtitle: subtitle,
        notes: chosen,
        icon: icon,
        color: color ?? _palette[collections.length % _palette.length],
      ));
    }

    final notesByMonth = <String, List<Note>>{};
    for (final note in notes) {
      final key = '${note.createdAt.year}-${note.createdAt.month}';
      notesByMonth.putIfAbsent(key, () => []).add(note);
    }

    // --- 1. Ce jour-la : la plus forte, donc servie en premier ---
    add(
      'Ce jour-là',
      'Le ${now.day} ${_getMonthName(now.month)}, vous écriviez…',
      pick(
        notes.where((n) =>
            n.createdAt.month == now.month &&
            n.createdAt.day == now.day &&
            n.createdAt.year != now.year).toList(),
        5,
      ),
      Icons.today_rounded,
      minimum: 1,
    );

    // --- 2. Il y a un an ---
    final oneYearAgo = DateTime(now.year - 1, now.month);
    add(
      'Il y a 1 an',
      '${_getMonthName(oneYearAgo.month)} ${oneYearAgo.year}',
      pick(notesByMonth['${oneYearAgo.year}-${oneYearAgo.month}'] ?? [], 5),
      Icons.calendar_today_rounded,
    );

    // --- 3. Le mois dernier ---
    final lastMonth = DateTime(now.year, now.month - 1);
    add(
      'Le mois dernier',
      _getMonthName(lastMonth.month),
      pick(notesByMonth['${lastMonth.year}-${lastMonth.month}'] ?? [], 5),
      Icons.history_rounded,
    );

    // --- 4. Votre premiere chronique ---
    final sorted = List<Note>.from(notes)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.isNotEmpty &&
        now.difference(sorted.first.createdAt).inDays > 30 &&
        !used.contains(sorted.first.id)) {
      used.add(sorted.first.id);
      add('Votre première chronique', 'Là où tout a commencé',
          [sorted.first], Icons.flag_rounded,
          minimum: 1);
    }

    // --- 5. Redecouvrez : oubliees depuis plus de deux mois ---
    add(
      'Redécouvrez',
      'Vous n\'y êtes pas revenu depuis longtemps',
      pick(
        notes
            .where((n) => now.difference(n.createdAt).inDays > 60)
            .toList(),
        6,
      ),
      Icons.explore_rounded,
      minimum: 3,
    );

    // --- 6. Auras intenses ---
    final auraNotes = notes.where((n) => NoteMood.hasGlow(n.mood)).toList();
    final auraPick = pick(auraNotes, 5);
    if (auraPick.isNotEmpty) {
      add(
        'Auras intenses',
        'Vos chroniques les plus vibrantes',
        auraPick,
        Icons.auto_awesome_rounded,
        minimum: 3,
        color: NoteMood.getEffectiveColor(
            auraPick.first.mood, auraPick.first.moodColor),
      );
    }

    // --- 7. Chroniques de nuit ---
    add(
      'Chroniques de nuit',
      'Écrites entre 22 h et l\'aube',
      pick(
        notes
            .where((n) => n.createdAt.hour >= 22 || n.createdAt.hour < 5)
            .toList(),
        5,
      ),
      Icons.dark_mode_rounded,
      minimum: 3,
    );

    // --- 8. Souvenirs visuels ---
    add(
      'Souvenirs visuels',
      'Vos chroniques illustrées',
      pick(notes.where((n) => n.imagePaths.isNotEmpty).toList(), 5),
      Icons.photo_library_rounded,
      minimum: 3,
    );

    // --- 9. Coups de cœur ---
    add(
      'Coups de cœur',
      'Celles que vous avez mises de côté',
      pick(notes.where((n) => n.isFavorite).toList(), 5),
      Icons.favorite_rounded,
      minimum: 2,
    );

    // --- 10. Moments intenses : les recits les plus longs ---
    final longNotes = List<Note>.from(notes)
      ..sort((a, b) => (b.title.length + b.content.length)
          .compareTo(a.title.length + a.content.length));
    add(
      'Moments intenses',
      'Vos récits les plus riches',
      pick(
        longNotes
            .take(14)
            .where((n) => (n.title.length + n.content.length) > 200)
            .toList(),
        5,
      ),
      Icons.local_fire_department_rounded,
      minimum: 3,
    );

    // Six collections au plus : au-dela, la page devient un catalogue et
    // chaque souvenir perd de sa valeur.
    return collections.take(6).toList();
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

  /// Ouvre les Stories plein écran (style Instagram)
  void _openSlideshow(MemoryCollection collection) {
    Navigator.push(
      context,
      PageRouteBuilder(
        // On ouvre bien le diaporama refait. Le bouton pointait encore vers
        // StoriesScreen, l'ancien ecran : toutes les ameliorations partaient
        // dans une classe que plus rien n'instanciait.
        pageBuilder: (_, __, ___) => _SlideshowScreen(collection: collection),
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

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.skyBlue,
      statusBarIconBrightness: Brightness.light,
    ));

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      // SafeArea : l'ancien en-tete gerait lui-meme la barre d'etat via
      // statusBarHeight. Le nouveau ne le fait pas, il faut donc la reserver
      // ici — sinon le titre passe sous l'heure et la batterie sur Android.
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
        onRefresh: _loadMemories,
        color: AppTheme.skyBlue,
        child: CustomScrollView(
          slivers: [
            screenHeaderSliver(
              width: width,
              pinnedHeight: 116,
              header: ScreenHeader(
                width: width,
                icon: Icons.auto_awesome_rounded,
                title: 'Souvenirs',
                subtitle: _collections.isEmpty
                    ? 'Vos anciennes chroniques remonteront ici'
                    : '${_collections.length} collection${_collections.length > 1 ? 's' : ''} à revisiter',
                accent: const Color(0xFFA78BFA),
                actions: [
                  RefreshAction(
                    onRefresh: _reshuffle,
                    tooltip: "Piocher d'autres souvenirs",
                    accent: const Color(0xFFA78BFA),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppTheme.skyBlue)),
              )
            else if (_collections.isEmpty)
              SliverFillRemaining(child: _buildEmpty(isDark))
            else ...[
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
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
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
        ),
      ),
      );
    });
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
              'Créez des chroniques pour générer des souvenirs',
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
  // Une rangee qui defile, plutot qu'un PageView plein cadre : a 85 % de la
  // largeur, une seule carte occupait 1 150 px sur desktop et on ne voyait
  // jamais la collection, seulement une note.
  final ScrollController _scroll = ScrollController();

  // 244 px etait une surcorrection apres les 1 150 px du PageView.
  static const double _cardW = 300;
  static const double _cardH = 212;
  static const double _gap = 14;

  bool _canLeft = false;
  bool _canRight = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncArrows);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncArrows());
  }

  @override
  void dispose() {
    _scroll.removeListener(_syncArrows);
    _scroll.dispose();
    super.dispose();
  }

  void _syncArrows() {
    if (!_scroll.hasClients) return;
    final left = _scroll.offset > 4;
    final right = _scroll.offset < _scroll.position.maxScrollExtent - 4;
    if (left != _canLeft || right != _canRight) {
      setState(() {
        _canLeft = left;
        _canRight = right;
      });
    }
  }

  void _nudge(int direction) {
    if (!_scroll.hasClients) return;
    final target = (_scroll.offset + direction * (_cardW + _gap))
        .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seul l'en-tete est borne : la rangee de cartes, elle, court d'un
          // bord a l'autre. Autrement on voyait ou le contenu s'arretait.
          ContentBounds(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.collection.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.collection.icon,
                        color: widget.collection.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.collection.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.collection.color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PlayButton(
                    color: widget.collection.color,
                    onTap: widget.onPlayTap,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // La rangee occupe toute la largeur. Les cartes ne sont pas coupees
          // net : elles s'effacent en fondu sur les cotes, si bien qu'on ne
          // devine aucune limite de conteneur.
          SizedBox(
            height: _cardH + 16,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.035, 0.965, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.collection.notes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: _gap),
                      itemBuilder: (context, index) => SizedBox(
                        width: _cardW,
                        child: _buildMemoryCard(
                            widget.collection.notes[index], index),
                      ),
                    ),
                  ),
                ),

                // Fleches posees par-dessus : elles ne volent plus de largeur
                // a la rangee, et disparaissent quand il n'y a rien a defiler.
                Positioned(
                  left: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_left_rounded,
                      enabled: _canLeft,
                      color: widget.collection.color,
                      isDark: widget.isDark,
                      onTap: () => _nudge(-1),
                    ),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _NavArrow(
                      icon: Icons.chevron_right_rounded,
                      enabled: _canRight,
                      color: widget.collection.color,
                      isDark: widget.isDark,
                      onTap: () => _nudge(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(Note note, int index) {
    final hasImage = note.imagePaths.isNotEmpty;
    final textColor =
        note.color.computeLuminance() > 0.5 ? AppTheme.textDark : Colors.white;

    return _MemoryCard(
      accent: widget.collection.color,
      onTap: () => widget.onNoteTap(note),
      child: Container(
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
                // Deux garde-fous cumules :
                //  - l'echelle de texte du systeme est bornee a 1,15. Au-dela,
                //    une carte de hauteur fixe deborde quoi qu'on fasse ;
                //  - ClipRect garantit qu'un residu est rogne proprement au
                //    lieu de peindre un avertissement de debordement.
                MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.15,
                  child: ClipRect(
                  child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    // spaceBetween au lieu d'un Spacer : la construction ne
                    // peut alors plus deborder, quels que soient les arrondis
                    // de hauteur de police. Les deux enfants sont flexibles,
                    // donc ils se compriment plutot que de forcer la carte.
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
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
                                height: 1.2,
                                color: hasImage
                                    ? Colors.white
                                    : textColor.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        ),
                      ),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            height: 1.4,
                            color: hasImage
                                ? Colors.white.withOpacity(0.85)
                                : textColor.withOpacity(0.7),
                          ),
                          maxLines: 2,
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
              ],
            ),
          ),
        ),
    );
  }
}

/// Écran Diaporama plein écran avec auto-play
class _SlideshowScreen extends StatefulWidget {
  final MemoryCollection collection;

  const _SlideshowScreen({required this.collection});

  @override
  State<_SlideshowScreen> createState() => _SlideshowScreenState();
}

/// Diaporama plein ecran.
///
/// Refonte : l'image occupe tout le cadre avec un flou de la meme photo en
/// arriere-plan (plus de bandes noires sur les formats verticaux), le texte
/// est borne pour rester lisible, et l'ecran se pilote entierement au clavier
/// — ce qui manquait completement sur desktop.
class _SlideshowScreenState extends State<_SlideshowScreen>
    with TickerProviderStateMixin {
  static const Duration _perSlide = Duration(milliseconds: 5200);

  final PageController _pages = PageController();
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: _perSlide,
  );

  int _index = 0;
  bool _playing = true;
  bool _chromeVisible = true;
  Timer? _chromeTimer;

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener(_onProgressDone);
    _progress.forward();
    _scheduleChromeHide();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _progress.removeStatusListener(_onProgressDone);
    _progress.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onProgressDone(AnimationStatus status) {
    if (status == AnimationStatus.completed && _playing) _next();
  }

  int get _count => widget.collection.notes.length;

  void _goTo(int i) {
    if (i < 0 || i >= _count) return;
    _pages.animateToPage(i,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic);
  }

  void _next() {
    if (_index >= _count - 1) {
      // Fin de la collection : on sort plutot que de boucler indefiniment.
      Navigator.of(context).maybePop();
      return;
    }
    _goTo(_index + 1);
  }

  void _prev() => _goTo(_index - 1);

  void _togglePlay() {
    setState(() {
      _playing = !_playing;
      if (_playing) {
        _progress.forward();
      } else {
        _progress.stop();
      }
    });
    _revealChrome();
  }

  /// Les commandes s'effacent apres quelques secondes pour laisser l'image
  /// respirer, et reviennent au moindre mouvement.
  void _scheduleChromeHide() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _playing) setState(() => _chromeVisible = false);
    });
  }

  void _revealChrome() {
    if (!_chromeVisible) setState(() => _chromeVisible = true);
    _scheduleChromeHide();
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
    } else if (k == LogicalKeyboardKey.space) {
      _togglePlay();
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _revealChrome();
      _next();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _revealChrome();
      _prev();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.collection.color;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          onHover: (_) => _revealChrome(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: _count,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _progress.forward(from: 0);
                },
                itemBuilder: (context, i) =>
                    _Slide(note: widget.collection.notes[i], accent: accent),
              ),

              // Zones de navigation : un clic a gauche recule, a droite avance.
              // Le centre met en pause. C'est le geste attendu d'un diaporama.
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _revealChrome();
                        _prev();
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _togglePlay,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        _revealChrome();
                        _next();
                      },
                    ),
                  ),
                ],
              ),

              _buildChrome(accent),

              // Le bouton de fermeture vit en dehors de la barre qui
              // s'efface : enferme dans son IgnorePointer, il devenait
              // inerte des que les commandes disparaissaient.
              Positioned(
                top: MediaQuery.of(context).padding.top + 14,
                right: 16,
                child: _CloseButton(
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChrome(Color accent) {
    final top = MediaQuery.of(context).padding.top;

    return IgnorePointer(
      ignoring: !_chromeVisible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 260),
        opacity: _chromeVisible ? 1 : 0,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(18, top + 14, 74, 22),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  // Segments facon stories : un par souvenir.
                  Row(
                    children: List.generate(_count, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: i < _index
                              ? _bar(1, accent)
                              : i == _index
                                  ? AnimatedBuilder(
                                      animation: _progress,
                                      builder: (_, __) =>
                                          _bar(_progress.value, accent),
                                    )
                                  : null,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.collection.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              '${_index + 1} sur $_count',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _RoundControl(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Précédent  ·  ←',
                        enabled: _index > 0,
                        onTap: _prev,
                      ),
                      const SizedBox(width: 8),
                      _RoundControl(
                        icon: _playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        tooltip: _playing ? 'Pause  ·  Espace' : 'Lire  ·  Espace',
                        filled: true,
                        accent: accent,
                        onTap: _togglePlay,
                      ),
                      const SizedBox(width: 8),
                      _RoundControl(
                        icon: Icons.chevron_right_rounded,
                        tooltip: 'Suivant  ·  →',
                        enabled: _index < _count - 1,
                        onTap: _next,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _bar(double value, Color accent) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: value.clamp(0.0, 1.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// Une diapositive : l'image en plein cadre, son propre flou en fond, et le
/// texte pose dessus dans une colonne bornee.
class _Slide extends StatelessWidget {
  final Note note;
  final Color accent;

  const _Slide({required this.note, required this.accent});

  @override
  Widget build(BuildContext context) {
    final hasImage = note.imagePaths.isNotEmpty;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage) ...[
          // Fond : la meme image, floutee et agrandie. Une photo verticale ne
          // laisse plus deux bandes noires sur les cotes.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
            child: Image.file(
              File(note.imagePaths.first),
              fit: BoxFit.cover,
              cacheWidth: (size.width * dpr * 0.25).round(),
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          ),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          Center(
            child: Image.file(
              File(note.imagePaths.first),
              fit: BoxFit.contain,
              cacheWidth: (size.width * dpr).round(),
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ] else
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.black, 0.55)!,
                  Colors.black,
                ],
              ),
            ),
          ),

        // Voile bas : le texte se detache sans assombrir toute l'image.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: size.height * 0.55,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.92),
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                28, 0, 28, 44 + MediaQuery.of(context).padding.bottom),
            child: ConstrainedBox(
              // Colonne bornee : un texte etale sur 1 900 px est illisible.
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          DateFormatter.formatRelativeDate(note.createdAt),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (note.isFavorite) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.favorite_rounded,
                            color: Color(0xFFE05252), size: 17),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (note.title.isNotEmpty)
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                    ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      note.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 15.5,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Commande ronde du diaporama.
class _RoundControl extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool enabled;
  final bool filled;
  final Color? accent;

  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.enabled = true,
    this.filled = false,
    this.accent,
  });

  @override
  State<_RoundControl> createState() => _RoundControlState();
}

class _RoundControlState extends State<_RoundControl> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    final accent = widget.accent ?? Colors.white;

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: on ? widget.onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: on ? 1 : 0.3,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: widget.filled ? 46 : 40,
              height: widget.filled ? 46 : 40,
              decoration: BoxDecoration(
                color: widget.filled
                    ? accent
                    : Colors.white.withValues(alpha: _hover && on ? 0.28 : 0.14),
                shape: BoxShape.circle,
                boxShadow: widget.filled && _hover
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                color: Colors.white,
                size: widget.filled ? 24 : 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modèle pour une collection de souvenirs
/// Ouvre le diaporama d'une periode, depuis n'importe ou.
///
/// Sert a la notification du matin : son contenu designe une distance dans
/// le temps (« il y a trois mois »), pas une chronique precise. Le diaporama
/// etait jusqu'ici une classe privee, donc injoignable hors de cet ecran.
Future<void> openPeriodSlideshow(BuildContext context, int days) async {
  final period = MemoryPeriod.byDays(days);
  if (period == null) return;

  await NoteService.instance.waitReady();
  final notes = period.matching(NoteService.instance.getAllNotes());
  if (notes.isEmpty || !context.mounted) return;

  final collection = MemoryCollection(
    title: period.title,
    subtitle: notes.length > 1
        ? '${notes.length} chroniques'
        : 'Une chronique',
    notes: notes,
    icon: Icons.history_rounded,
    color: AppTheme.skyBlue,
  );

  if (!context.mounted) return;
  Navigator.push(
    context,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => _SlideshowScreen(collection: collection),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

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

/// Carte d'un souvenir : elle reagit au survol comme le reste de l'app.
class _MemoryCard extends StatefulWidget {
  final Widget child;
  final Color accent;
  final VoidCallback onTap;

  const _MemoryCard({
    required this.child,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<_MemoryCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..translate(0.0, _hover ? -5.0 : 0.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.accent.withValues(alpha: 0.34),
                      blurRadius: 26,
                      spreadRadius: -2,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fleche de defilement. Elle etait un simple Icon : elle avait l'air
/// cliquable mais n'etait reliee a rien.
class _NavArrow extends StatefulWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_NavArrow> createState() => _NavArrowState();
}

class _NavArrowState extends State<_NavArrow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: on ? widget.onTap : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: on ? 1 : 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: on && _hover
                  ? widget.color
                  : (widget.isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.045)),
              shape: BoxShape.circle,
              boxShadow: on && _hover
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: on && _hover
                  ? Colors.white
                  : (widget.isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMuted),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton de lancement du diaporama.
class _PlayButton extends StatefulWidget {
  final Color color;
  final VoidCallback onTap;

  const _PlayButton({required this.color, required this.onTap});

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Lancer le diaporama',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapUp: (_) => setState(() => _down = false),
          onTapCancel: () => setState(() => _down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 110),
            scale: _down ? 0.94 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color,
                    Color.lerp(widget.color, Colors.black, 0.22)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: _hover ? 0.48 : 0.26),
                    blurRadius: _hover ? 18 : 10,
                    offset: Offset(0, _hover ? 6 : 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text('Diaporama',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fermeture du diaporama : visible en permanence, contrastee, avec son
/// raccourci rappele. C'est la sortie de secours de l'ecran, elle ne doit
/// jamais disparaitre.
class _CloseButton extends StatefulWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Fermer  ·  Échap',
      waitDuration: const Duration(milliseconds: 300),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
                horizontal: _hover ? 16 : 13, vertical: 11),
            decoration: BoxDecoration(
              color: _hover
                  ? const Color(0xFFD1544B)
                  : Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: _hover ? 0.9 : 0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: _hover
                      ? const Padding(
                          padding: EdgeInsets.only(left: 7),
                          child: Text(
                            'Fermer',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
