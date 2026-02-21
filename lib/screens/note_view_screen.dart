import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../widgets/image_gallery_editor.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'member_picker_screen.dart';
import '../widgets/rich_text_viewer.dart';

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
  String _displayedContent = '';
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

    // Demarrer l'effet typewriter
    _startTypewriter();
  }

  @override
  void dispose() {
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
        setState(() {
          _displayedContent =
              widget.note.content.substring(0, _currentContentIndex + 1);
          _currentContentIndex++;
        });
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
      _displayedContent = widget.note.content;
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
    final auraColor = NoteMood.getEffectiveColor(widget.note.mood, widget.note.moodColor);
    final moodData = NoteMood.fromKey(widget.note.mood);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: GestureDetector(
          onTap: _waitingForTap ? _continueChronique : null,
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              _buildAppBar(context, textColor, isDark),
              Expanded(
                child: Stack(
                  children: [
                    // Aura ambient glow overlay
                    if (hasAura)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.topCenter,
                                radius: 1.4,
                                colors: [
                                  auraColor.withOpacity(isDark ? 0.35 : 0.12),
                                  auraColor.withOpacity(isDark ? 0.15 : 0.04),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Aura badge flottant — positionné en bas à droite
                    if (moodData != null && hasAura)
                      Positioned(
                        bottom: 24,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: auraColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: auraColor.withOpacity(0.5),
                                blurRadius: 14,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(moodData.icon, size: 14, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                moodData.label.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Images (affichees directement)
                          if (widget.note.imagePaths.isNotEmpty) ...[
                            ImageGalleryEditor(
                              imagePaths: widget.note.imagePaths,
                              textColor: textColor,
                              readOnly: true,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Meta info
                          _buildMeta(textColor),
                          const SizedBox(height: 20),

                          // Titre avec effet typewriter
                          if (widget.note.title.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    _displayedTitle,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                                if (!_titleComplete)
                                  _buildCursor(textColor, large: true),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Contenu avec RichTextViewer
                          if (widget.note.content.isNotEmpty &&
                              _titleComplete) ...[
                            RichTextViewer(
                              key: _contentViewerKey,
                              content: widget.note.content,
                              formattedContent: widget.note.formattedContent,
                              skip: _chroniqueFinished || _contentComplete,
                              chunkSize: _chunkSize,
                              speed: Duration(milliseconds: _typeSpeed),
                              baseStyle: TextStyle(
                                fontSize: 16,
                                color: textColor.withOpacity(0.85),
                                height: 1.8,
                                fontFamily: 'Georgia',
                              ),
                              onPause: () => setState(() => _waitingForTap = true),
                              onComplete: _finishChronique,
                            ),
                          ],

                          // "Tap pour continuer"
                          if (_waitingForTap)
                            _buildTapToContinue(textColor, isDark),

                          // "Termine" - fin de la chronique
                          if (_chroniqueFinished) _buildFinished(textColor, isDark),

                          // Empty state
                          if (widget.note.title.isEmpty &&
                              widget.note.content.isEmpty &&
                              widget.note.imagePaths.isEmpty)
                            _buildEmptyState(textColor),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),

                    // Bouton skip
                    if (!_chroniqueFinished)
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: _buildSkipButton(isDark),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildTapToContinue(Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1.0),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: child,
            );
          },
          onEnd: () {}, // Pour faire boucler l'animation
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppTheme.skyBlue.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: AppTheme.skyBlue,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Touchez pour continuer...',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.skyBlue,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFinished(Color textColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 50),
      child: Center(
        child: ScaleTransition(
          scale: _finishedScale,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.skyBlue.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: AppTheme.skyBlue,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Termine',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.skyBlue,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Fin de la chronique.',
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _skipToEnd,
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.skip_next_rounded,
                size: 18,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 6),
              Text(
                'Passer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(Icons.note_outlined,
                size: 64, color: textColor.withOpacity(0.25)),
            const SizedBox(height: 16),
            Text(
              'Chronique vide',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor.withOpacity(0.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, Color textColor, bool isDark) {
    final isSignedIn = AuthService.instance.isSignedIn;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
          ),
          const Spacer(),
          // Bouton partager (seulement si connecté)
          if (isSignedIn) ...[
            _buildToolButton(Icons.share_outlined, textColor,
                () => _showShareDialog(), isDark),
            const SizedBox(width: 4),
          ],
          _buildToolButton(
              Icons.edit_outlined, textColor, widget.onEdit, isDark),
          const SizedBox(width: 4),
          _buildToolButton(Icons.delete_outline_rounded, textColor,
              () => _confirmDelete(context), isDark),
          const SizedBox(width: 4),
          _buildToolButton(
            widget.note.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            widget.note.isFavorite ? AppTheme.skyBlue : textColor,
            () {
              widget.onToggleFavorite();
              if (mounted) setState(() {});
            },
            isDark,
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

  Widget _buildToolButton(
      IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildMeta(Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded,
                  size: 14, color: textColor.withOpacity(0.6)),
              const SizedBox(width: 6),
              Text(
                DateFormatter.formatRelativeDate(widget.note.modifiedAt),
                style: TextStyle(
                    fontSize: 12,
                    color: textColor.withOpacity(0.6),
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        if (widget.note.isFavorite) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite_rounded, size: 14, color: AppTheme.skyBlue),
                const SizedBox(width: 6),
                Text('Favori',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.skyBlue,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
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
