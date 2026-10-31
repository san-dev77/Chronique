import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/note.dart';
import '../models/note_mood.dart';
import '../widgets/note_hero_image.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'member_picker_screen.dart';
import '../widgets/reading_chrome.dart';
import '../widgets/rich_text_viewer.dart';
import '../widgets/save_flash.dart';
import '../utils/responsive.dart';
import '../widgets/motion.dart';

class NoteViewScreen extends StatefulWidget {
  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  const NoteViewScreen({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  @override
  State<NoteViewScreen> createState() => _NoteViewScreenState();
}

class _NoteViewScreenState extends State<NoteViewScreen>
    with TickerProviderStateMixin {
  // Typewriter state
  String _displayedTitle = '';
  int _currentTitleIndex = 0;
  int _currentContentIndex = 0;
  Timer? _typeTimer;

  // Chronique mode
  bool _titleComplete = false;
  bool _contentComplete = false;
  bool _waitingForTap = false;
  bool _chroniqueFinished = false;
  int _chunkSize = 150; // Caracteres par chunk
  int _currentChunkEnd = 0;

  // Key for RichTextViewer to access continueTyping
  final GlobalKey<RichTextViewerState> _contentViewerKey = GlobalKey();

  // Animation
  late AnimationController _cursorController;
  late AnimationController _finishedController;
  late Animation<double> _finishedScale;

  // Vitesse de frappe (ms par caractere)
  final int _typeSpeed = 15;

  /// Defilement, progression de lecture, et passage sous la barre du haut.
  final ScrollController _scroll = ScrollController();
  double _progress = 0;
  bool _scrolled = false;

  /// Preference : afficher la chronique d'un coup, sans la derouler.
  ///
  /// L'effet machine a ecrire est beau la premiere fois. A la dixieme
  /// relecture d'un souvenir, c'est un obstacle entre soi et son texte. Le
  /// choix se retient donc d'une fois sur l'autre.
  static const String _instantKey = 'read_instantly';
  bool _instant = false;

  @override
  void initState() {
    super.initState();

    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 530),
      vsync: this,
    )..repeat(reverse: true);

    _finishedController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _finishedScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _finishedController, curve: Curves.elasticOut),
    );

    _scroll.addListener(_onScroll);

    // Demarrer l'effet typewriter
    _startTypewriter();

    // La preference arrive une poignee de millisecondes plus tard : le
    // deroule a peine commence, l'interruption ne se voit pas.
    _restoreInstant();
  }

  Future<void> _restoreInstant() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final instant = prefs.getBool(_instantKey) ?? false;
      if (!mounted) return;
      setState(() => _instant = instant);
      if (instant && !_chroniqueFinished) _skipToEnd();
    } catch (_) {
      // Preference illisible : on garde le deroule, c'est le comportement
      // d'origine.
    }
  }

  Future<void> _setInstant(bool value) async {
    setState(() => _instant = value);
    if (value && !_chroniqueFinished) _skipToEnd();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_instantKey, value);
    } catch (_) {
      // Sans persistance, le choix vaut au moins pour cette lecture.
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    final offset = _scroll.offset;
    final progress = max > 0 ? (offset / max).clamp(0.0, 1.0) : 0.0;
    final scrolled = offset > 12;
    if (progress != _progress || scrolled != _scrolled) {
      setState(() {
        _progress = progress;
        _scrolled = scrolled;
      });
    }
  }

  /// Copie la chronique en texte simple.
  ///
  /// Titre, citation puis corps : ce que l'on colle ailleurs doit se lire
  /// seul, sans le balisage du texte enrichi.
  Future<void> _copy() async {
    final note = widget.note;
    final parts = <String>[];
    if (note.title.trim().isNotEmpty) parts.add(note.title.trim());
    if (note.quote != null && note.quote!.trim().isNotEmpty) {
      parts.add('\u00ab\u00a0${note.quote!.trim()}\u00a0\u00bb');
    }
    if (note.content.trim().isNotEmpty) parts.add(note.content.trim());

    if (parts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cette chronique est vide.'),
      ));
      return;
    }

    await Clipboard.setData(ClipboardData(text: parts.join('\n\n')));
    if (!mounted) return;
    await showSaveFlash(context, message: 'Copi\u00e9');
  }

  @override
  void dispose() {
    _scroll.dispose();
    _typeTimer?.cancel();
    _cursorController.dispose();
    _finishedController.dispose();
    super.dispose();
  }

  void _startTypewriter() {
    // Commencer par le titre
    if (widget.note.title.isNotEmpty) {
      _typeTitle();
    } else {
      _titleComplete = true;
      _startContentTypewriter();
    }
  }

  void _typeTitle() {
    _typeTimer = Timer.periodic(Duration(milliseconds: _typeSpeed), (timer) {
      if (_currentTitleIndex < widget.note.title.length) {
        setState(() {
          _displayedTitle =
              widget.note.title.substring(0, _currentTitleIndex + 1);
          _currentTitleIndex++;
        });
      } else {
        timer.cancel();
        setState(() => _titleComplete = true);
        // Petite pause puis demarrer le contenu
        Future.delayed(const Duration(milliseconds: 400), () {
          _startContentTypewriter();
        });
      }
    });
  }

  void _startContentTypewriter() {
    if (widget.note.content.isEmpty) {
      _finishChronique();
      return;
    }

    _currentChunkEnd = _chunkSize.clamp(0, widget.note.content.length);
    _typeContent();
  }

  void _typeContent() {
    _typeTimer = Timer.periodic(Duration(milliseconds: _typeSpeed), (timer) {
      if (_currentContentIndex < _currentChunkEnd) {
        // Le texte est rendu par RichTextViewer, qui anime lui-meme sa
        // frappe. Ce compteur ne sert qu'a cadencer les pauses : l'entourer
        // d'un setState reconstruisait tout l'ecran a chaque caractere.
        _currentContentIndex++;
      } else {
        timer.cancel();

        // Verifier si on a encore du contenu
        if (_currentContentIndex >= widget.note.content.length) {
          _finishChronique();
        } else {
          // Attendre un tap pour continuer
          setState(() => _waitingForTap = true);
        }
      }
    });
  }

  void _continueChronique() {
    if (!_waitingForTap) return;

    setState(() => _waitingForTap = false);
    
    // Appeler continueTyping sur le RichTextViewer
    _contentViewerKey.currentState?.continueTyping();

    // Calculer le prochain chunk (pour l'ancien système, peut être supprimé)
    _currentChunkEnd = (_currentContentIndex + _chunkSize)
        .clamp(0, widget.note.content.length);

    _typeContent();
  }

  void _finishChronique() {
    setState(() {
      _contentComplete = true;
      _chroniqueFinished = true;
    });
    _finishedController.forward();
  }

  void _skipToEnd() {
    _typeTimer?.cancel();
    setState(() {
      _displayedTitle = widget.note.title;
      _titleComplete = true;
      _contentComplete = true;
      _waitingForTap = false;
      _chroniqueFinished = true;
    });
    _finishedController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.bgDark : widget.note.color;
    final textColor = _getTextColor(bgColor, isDark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.skyBlue,
      statusBarIconBrightness: Brightness.light,
    ));

    final hasAura = NoteMood.hasGlow(widget.note.mood);
    final auraColor =
        NoteMood.getEffectiveColor(widget.note.mood, widget.note.moodColor);
    final accent = hasAura ? auraColor : AppTheme.skyBlue;
    final wide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: bgColor,
      body: Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.escape): _CloseIntent(),
          SingleActivator(LogicalKeyboardKey.keyE, control: true): _EditIntent(),
        },
        child: Actions(
          actions: {
            _CloseIntent: CallbackAction<_CloseIntent>(onInvoke: (_) {
              Navigator.maybePop(context);
              return null;
            }),
            _EditIntent: CallbackAction<_EditIntent>(onInvoke: (_) {
              widget.onEdit();
              return null;
            }),
          },
          child: Focus(
            autofocus: true,
            child: SafeArea(
              child: GestureDetector(
                onTap: _waitingForTap ? _continueChronique : null,
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    _buildAppBar(context, textColor, isDark, accent),
                    ReadingProgress(value: _progress, accent: accent),
                    Expanded(
                      child: Stack(
                        children: [
                          // Lueur d'ambiance : la teinte de l'aura descend du
                          // haut, sans jamais toucher la zone de lecture.
                          if (hasAura)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: Alignment.topCenter,
                                      radius: 1.3,
                                      stops: const [0, 0.42, 1],
                                      colors: [
                                        auraColor.withValues(
                                            alpha: isDark ? 0.26 : 0.10),
                                        auraColor.withValues(
                                            alpha: isDark ? 0.10 : 0.035),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          _buildReader(textColor, isDark, accent, hasAura,
                              auraColor, wide),
                          if (!_chroniqueFinished)
                            Positioned(
                              bottom: 20,
                              left: 0,
                              right: 0,
                              child: Center(child: _buildSkipButton(isDark)),
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
    );
  }

  /// La colonne de lecture.
  ///
  /// Bornee a 680 px : au-dela, l'oeil perd la ligne suivante en revenant a
  /// la marge. C'est la mesure qui compte le plus dans un ecran de lecture.
  Widget _buildReader(Color textColor, bool isDark, Color accent, bool hasAura,
      Color auraColor, bool wide) {
    final note = widget.note;
    final hasQuote = note.quote != null && note.quote!.trim().isNotEmpty;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.imagePaths.isNotEmpty) ...[
          // L'image reste un peu en arriere quand le texte monte : c'est ce
          // decalage qui donne la profondeur. Il ne coute qu'une
          // translation, et seul ce sous-arbre se reconstruit — le
          // ScrollController est ecoute ici, pas par la page entiere.
          Parallax(
            controller: _scroll,
            child: NoteHeroImage(
              imagePaths: note.imagePaths,
              auraColor: hasAura ? auraColor : null,
            ),
          ),
          const SizedBox(height: 28),
        ],
        _buildMeta(textColor, accent, hasAura, auraColor),
        const SizedBox(height: 22),
        if (note.title.isNotEmpty) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _displayedTitle,
                  style: TextStyle(
                    fontSize: wide ? 34 : 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ),
              if (!_titleComplete) _buildCursor(textColor, large: true),
            ],
          ),
          const SizedBox(height: 20),
        ],
        if (hasQuote && _titleComplete) ...[
          _buildPullQuote(note.quote!.trim(), textColor, accent, wide),
          const SizedBox(height: 24),
        ],
        if (note.content.isNotEmpty && _titleComplete)
          RichTextViewer(
            key: _contentViewerKey,
            content: note.content,
            formattedContent: note.formattedContent,
            skip: _chroniqueFinished || _contentComplete,
            chunkSize: _chunkSize,
            speed: Duration(milliseconds: _typeSpeed),
            baseStyle: TextStyle(
              fontSize: wide ? 17.5 : 16.5,
              color: textColor.withValues(alpha: 0.88),
              height: 1.85,
              letterSpacing: 0.1,
              fontFamily: 'Georgia',
            ),
            onPause: () => setState(() => _waitingForTap = true),
            onComplete: _finishChronique,
          ),
        if (_waitingForTap) _buildTapToContinue(textColor, isDark),
        if (_chroniqueFinished) _buildFinished(textColor, isDark, accent),
        // Une citation seule est une chronique a part entiere : l oubli de
        // ce cas affichait « Chronique vide » sous la phrase qu on venait
        // justement de lire.
        if (note.title.isEmpty &&
            note.content.isEmpty &&
            note.imagePaths.isEmpty &&
            !hasQuote)
          _buildEmptyState(textColor),
        const SizedBox(height: 110),
      ],
    );

    return SingleChildScrollView(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(wide ? 32 : 22, 18, wide ? 32 : 22, 0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          // Le texte devient selectionnable une fois le deroule termine :
          // pendant la frappe, une selection serait emportee a chaque
          // caractere ajoute.
          child: _chroniqueFinished || _contentComplete
              ? SelectionArea(child: column)
              : column,
        ),
      ),
    );
  }

  /// La citation, en exergue.
  ///
  /// L'encadre centre precedent la traitait comme une note de bas de page.
  /// Une citation dans une chronique, c'est une respiration : elle merite le
  /// corps de texte le plus grand de l'ecran.
  Widget _buildPullQuote(
      String text, Color textColor, Color accent, bool wide) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [accent, accent.withValues(alpha: 0.25)],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: wide ? 20 : 18,
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.55,
                  letterSpacing: -0.2,
                  color: textColor.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCursor(Color textColor, {bool large = false}) {
    return AnimatedBuilder(
      animation: _cursorController,
      builder: (context, child) {
        return Opacity(
          opacity: _cursorController.value,
          child: Container(
            width: large ? 3 : 2,
            height: large ? 30 : 20,
            margin: const EdgeInsets.only(left: 2, bottom: 2),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  /// L'invitation a poursuivre, pendant le deroule.
  Widget _buildTapToContinue(Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 34),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: AppMotion.slow,
          curve: AppMotion.enter,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withValues(alpha: isDark ? 0.16 : 0.09),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: AppTheme.skyBlue.withValues(alpha: 0.28)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.skyBlue, size: 19),
                const SizedBox(width: 8),
                Text(
                  'Continuer la lecture',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.skyBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La fin de la chronique.
  ///
  /// Un « TERMINE » de trente-deux points criait la fin d'un texte intime.
  /// Un filet, un point, et la date : la chronique se referme au lieu de
  /// s'interrompre.
  Widget _buildFinished(Color textColor, bool isDark, Color accent) {
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: ScaleTransition(
        scale: _finishedScale,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accent.withValues(alpha: 0),
                        accent.withValues(alpha: 0.35),
                      ]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.auto_awesome_rounded,
                      size: 16, color: accent.withValues(alpha: 0.75)),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        accent.withValues(alpha: 0.35),
                        accent.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              DateFormatter.formatFullDate(widget.note.createdAt),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: textColor.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Interrompre le deroule pour tout afficher.
  Widget _buildSkipButton(bool isDark) {
    return _SkipButton(onTap: _skipToEnd, isDark: isDark);
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(Icons.note_outlined,
                size: 64, color: textColor.withValues(alpha: 0.25)),
            const SizedBox(height: 16),
            Text(
              'Chronique vide',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  /// La barre du haut.
  ///
  /// Elle porte le titre des que la chronique defile : sur un texte long, on
  /// finit par ne plus savoir ce qu'on lit. Les actions secondaires passent
  /// dans un menu — six icones alignees, c'etait une palette d'outils posee
  /// au-dessus d'un texte.
  Widget _buildAppBar(
      BuildContext context, Color textColor, bool isDark, Color accent) {
    final isSignedIn = AuthService.instance.isSignedIn;
    final title = widget.note.title.trim();

    return AnimatedContainer(
      duration: AppMotion.medium,
      curve: AppMotion.enter,
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: textColor.withValues(alpha: _scrolled ? 0.10 : 0),
          ),
        ),
      ),
      child: Row(
        children: [
          ToolButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Retour  ·  Échap',
            color: textColor,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnimatedOpacity(
              duration: AppMotion.medium,
              opacity: _scrolled && title.isNotEmpty ? 1 : 0,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ToolButton(
            icon: Icons.copy_rounded,
            tooltip: 'Copier la chronique',
            color: textColor,
            onTap: _copy,
          ),
          const SizedBox(width: 5),
          ToolButton(
            icon: Icons.edit_outlined,
            tooltip: 'Modifier  ·  Ctrl+E',
            color: textColor,
            onTap: widget.onEdit,
          ),
          const SizedBox(width: 5),
          ToolButton(
            icon: widget.note.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            tooltip: widget.note.isFavorite
                ? 'Retirer des favoris'
                : 'Mettre en favori',
            color: textColor,
            activeColor: const Color(0xFFE05252),
            active: widget.note.isFavorite,
            onTap: () {
              widget.onToggleFavorite();
              if (mounted) setState(() {});
            },
          ),
          const SizedBox(width: 5),
          _buildMoreMenu(textColor, isDark, isSignedIn),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(Color textColor, bool isDark, bool isSignedIn) {
    return PopupMenuButton<String>(
      tooltip: 'Plus',
      position: PopupMenuPosition.under,
      color: isDark ? AppTheme.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      onSelected: (value) {
        switch (value) {
          case 'share':
            _showShareDialog();
          case 'instant':
            _setInstant(!_instant);
          case 'delete':
            _confirmDelete(context);
        }
      },
      itemBuilder: (context) => [
        if (isSignedIn)
          _menuItem('share', Icons.share_outlined, 'Partager', textColor),
        // Le deroule est beau la premiere fois et pesant a la dixieme : le
        // choix se garde d'une lecture a l'autre.
        PopupMenuItem<String>(
          value: 'instant',
          child: Row(
            children: [
              Icon(
                _instant
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 19,
                color: _instant ? AppTheme.skyBlue : textColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Text(
                'Afficher d’un coup',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline_rounded,
                  size: 19, color: Color(0xFFE05252)),
              const SizedBox(width: 12),
              const Text(
                'Supprimer',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE05252),
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.more_horiz_rounded, color: textColor, size: 20),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color textColor) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showShareDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberPickerScreen(note: widget.note),
      ),
    );
  }

  /// Les reperes de la chronique : quand, combien de temps, quelle aura.
  Widget _buildMeta(
      Color textColor, Color accent, bool hasAura, Color auraColor) {
    final note = widget.note;
    final minutes = readingMinutes('${note.title} ${note.content}');
    final moodLabel = NoteMood.getDisplayLabel(note.mood);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        MetaPill(
          icon: Icons.event_rounded,
          label: DateFormatter.formatRelativeDate(note.createdAt),
          textColor: textColor,
        ),
        if (note.content.trim().isNotEmpty)
          MetaPill(
            icon: Icons.schedule_rounded,
            label: '$minutes min de lecture',
            textColor: textColor,
          ),
        // Une teinte libre n a pas de nom : l etiquette affichait « Aura »,
        // ce qui n apprend rien. La lueur de fond dit deja la couleur.
        if (hasAura && moodLabel.isNotEmpty && moodLabel != 'Aura')
          MetaPill(
            dot: auraColor,
            label: moodLabel,
            textColor: textColor,
            tint: auraColor,
          ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer cette chronique ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Cette action est irreversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler',
                style: TextStyle(
                    color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.skyBlue),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Color _getTextColor(Color bg, bool isDark) {
    if (isDark) return AppTheme.textLight;
    return bg.computeLuminance() > 0.5 ? AppTheme.textDark : Colors.white;
  }
}

/// Fermer la lecture (Échap).
class _CloseIntent extends Intent {
  const _CloseIntent();
}

/// Passer a l'edition (Ctrl+E).
class _EditIntent extends Intent {
  const _EditIntent();
}

/// Bouton « Tout afficher », pose au bas du deroule.
///
/// « Passer » laissait croire qu'on sautait du contenu. On ne saute rien :
/// on cesse d'attendre.
class _SkipButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _SkipButton({required this.onTap, required this.isDark});

  @override
  State<_SkipButton> createState() => _SkipButtonState();
}

class _SkipButtonState extends State<_SkipButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final base = isDark ? Colors.white : Colors.black;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
                ? AppTheme.skyBlue.withValues(alpha: isDark ? 0.20 : 0.11)
                : base.withValues(alpha: isDark ? 0.10 : 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: _hover
                  ? AppTheme.skyBlue.withValues(alpha: 0.38)
                  : base.withValues(alpha: isDark ? 0.16 : 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.unfold_more_rounded,
                  size: 16,
                  color: _hover
                      ? AppTheme.skyBlue
                      : base.withValues(alpha: isDark ? 0.7 : 0.55)),
              const SizedBox(width: 7),
              Text(
                'Tout afficher',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: _hover
                      ? AppTheme.skyBlue
                      : base.withValues(alpha: isDark ? 0.7 : 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
