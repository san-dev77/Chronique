import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shared_note.dart';
import '../models/reaction.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../services/image_base64_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

/// Un widget dédié pour l'effet machine à écrire afin d'éviter de reconstruire tout l'écran
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration speed;
  final Duration startDelay;
  final bool skip;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.speed = const Duration(milliseconds: 25),
    this.startDelay = Duration.zero,
    this.skip = false,
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText>
    with TickerProviderStateMixin {
  String _displayedText = '';
  int _currentIndex = 0;
  Timer? _timer;
  late AnimationController _cursorController;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    if (widget.skip) {
      _displayedText = widget.text;
      _currentIndex = widget.text.length;
    } else {
      if (widget.startDelay == Duration.zero) {
        _startTyping();
      } else {
        Future.delayed(widget.startDelay, _startTyping);
      }
    }
  }

  @override
  void didUpdateWidget(TypewriterText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.skip && !oldWidget.skip) {
      _timer?.cancel();
      setState(() {
        _displayedText = widget.text;
        _currentIndex = widget.text.length;
      });
      // Utiliser addPostFrameCallback pour éviter l'erreur "setState during build"
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onComplete?.call();
      });
    }
  }

  void _startTyping() {
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_currentIndex < widget.text.length) {
        if (mounted) {
          setState(() {
            _displayedText = widget.text.substring(0, _currentIndex + 1);
            _currentIndex++;
          });
        }
      } else {
        timer.cancel();
        // Optionnel: sécuriser ici aussi
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(text: _displayedText, style: widget.style),
          if (_currentIndex < widget.text.length)
            WidgetSpan(
              child: AnimatedBuilder(
                animation: _cursorController,
                builder: (context, child) => Opacity(
                  opacity: _cursorController.value,
                  child: Container(
                    width: 2,
                    height: (widget.style.fontSize ?? 16) * 1.2,
                    color: AppTheme.skyBlue,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Écran pour visualiser une note partagée avec réactions et commentaires
class SharedNoteViewScreen extends StatefulWidget {
  final SharedNote sharedNote;

  const SharedNoteViewScreen({super.key, required this.sharedNote});

  @override
  State<SharedNoteViewScreen> createState() => _SharedNoteViewScreenState();
}

class _SharedNoteViewScreenState extends State<SharedNoteViewScreen>
    with TickerProviderStateMixin {
  late Stream<SharedNote?> _noteStream;
  final _commentController = TextEditingController();
  bool _isReacting = false;
  bool _isSendingComment = false;
  bool _showContent = false;
  bool _storyFinished = false;

  late AnimationController _finishedController;
  late Animation<double> _finishedScale;

  @override
  void initState() {
    super.initState();
    _noteStream = SharingService.instance.watchSharedNote(widget.sharedNote.id);

    _finishedController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _finishedScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _finishedController, curve: Curves.elasticOut),
    );

    // Petit délai pour laisser les images s'afficher avant de commencer le texte
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  void dispose() {
    _finishedController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _finishStory() {
    if (mounted) {
      setState(() => _storyFinished = true);
      _finishedController.forward();
    }
  }

  void _skipToEnd() {
    if (mounted) {
      setState(() {
        _showContent = true;
        _storyFinished = true;
      });
      _finishedController.forward();
    }
  }

  Future<void> _toggleReaction(SharedNote note, String emoji) async {
    if (_isReacting) return;

    setState(() => _isReacting = true);

    try {
      await SharingService.instance.toggleReaction(note, emoji);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReacting = false);
    }
  }

  Future<void> _sendComment(String sharedNoteId) async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _isSendingComment) return;

    setState(() => _isSendingComment = true);

    try {
      await SharingService.instance.addComment(sharedNoteId, commentText);
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.skyBlue;
    final userId = AuthService.instance.userId ?? '';
    final isRecipient = widget.sharedNote.recipientId == userId ||
        widget.sharedNote.recipientEmail ==
            AuthService.instance.userEmail?.toLowerCase();

    return StreamBuilder<SharedNote?>(
      stream: _noteStream,
      initialData: widget.sharedNote,
      builder: (context, snapshot) {
        final note = snapshot.data ?? widget.sharedNote;
        final noteColor = Color(note.color);
        final textColor = _getTextColor(noteColor, isDark);

        return Scaffold(
          backgroundColor: isDark ? AppTheme.bgDark : noteColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              isRecipient
                  ? 'De ${note.senderName}'
                  : 'Partagé avec ${note.recipientEmail}',
              style: TextStyle(
                color: textColor.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isDark ? AppTheme.bgDark : noteColor,
                  isDark
                      ? AppTheme.bgDark.withOpacity(0.8)
                      : noteColor.withOpacity(0.9),
                ],
              ),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(24,
                            MediaQuery.of(context).padding.top + 70, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. IMAGES D'ABORD - Stable, pas de rebuild flickering
                            if (note.imagesBase64.isNotEmpty) ...[
                              _buildImageGallery(note.imagesBase64),
                              const SizedBox(height: 32),
                            ],

                            // 2. TITRE - Typewriter isolé
                            if (note.title.isNotEmpty && _showContent)
                              TypewriterText(
                                key: ValueKey('title_${note.id}'),
                                text: note.title,
                                skip: _storyFinished,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  height: 1.1,
                                  letterSpacing: -0.5,
                                ),
                              ),

                            if (note.title.isNotEmpty)
                              const SizedBox(height: 24),

                            // 3. CONTENU - Typewriter isolé
                            if (note.content.isNotEmpty && _showContent)
                              TypewriterText(
                                key: ValueKey('content_${note.id}'),
                                text: note.content,
                                skip: _storyFinished,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: textColor.withOpacity(0.9),
                                  height: 1.7,
                                  fontFamily: 'Georgia',
                                ),
                                startDelay: const Duration(milliseconds: 800),
                                onComplete: _finishStory,
                              ),

                            // Métadonnées
                            const SizedBox(height: 48),
                            _buildMetaBadge(note, textColor),

                            // Terminé
                            if (_storyFinished)
                              _buildFinished(textColor, isDark, primaryColor),

                            const SizedBox(height: 40),
                            _buildReactionsAndComments(
                                note, isDark, primaryColor),

                            const SizedBox(height: 160),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Barre de réactions (uniquement destinataire) - MAINTENANT DANS LE STACK
                if (isRecipient)
                  _buildInteractionBar(note, isDark, primaryColor),

                // Bouton Skip
                if (!_storyFinished)
                  Positioned(
                    bottom: isRecipient ? 150 : 40,
                    right: 24,
                    child: _buildSkipButton(isDark, textColor),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaBadge(SharedNote note, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_edu_rounded,
              size: 16, color: textColor.withOpacity(0.5)),
          const SizedBox(width: 8),
          Text(
            'Partagé ${DateFormatter.formatRelativeDate(note.sharedAt)}',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipButton(bool isDark, Color textColor) {
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
                : textColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.2)
                  : textColor.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.skip_next_rounded,
                size: 18,
                color: isDark ? Colors.white70 : textColor.withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'Passer',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinished(Color textColor, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      child: Center(
        child: ScaleTransition(
          scale: _finishedScale,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  color: primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Partage consulté',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageGallery(List<String> imagesBase64) {
    return Column(
      children: imagesBase64.map((base64) {
        final imageWidget = ImageBase64Service.instance.decodeBase64ToImage(
          base64,
          fit: BoxFit.cover,
        );

        if (imageWidget == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageWidget,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReactionsAndComments(
      SharedNote note, bool isDark, Color primaryColor) {
    final emojiReactions =
        note.reactions.where((r) => r.isEmojiReaction).toList();
    final comments = note.reactions.where((r) => r.isComment).toList();
    final noteColor = Color(note.color);
    final textColor = _getTextColor(noteColor, isDark);

    if (emojiReactions.isEmpty && comments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Réactions emojis
        if (emojiReactions.isNotEmpty) ...[
          Text(
            'Réactions',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _groupReactionsByEmoji(emojiReactions).entries.map((entry) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      entry.value.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // Commentaires
        if (comments.isNotEmpty) ...[
          Text(
            'Commentaires (${comments.length})',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          ...comments.map(
              (comment) => _buildCommentCard(comment, isDark, primaryColor)),
        ],
      ],
    );
  }

  Map<String, int> _groupReactionsByEmoji(List<Reaction> reactions) {
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    return counts;
  }

  Widget _buildCommentCard(Reaction comment, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: primaryColor.withOpacity(0.15),
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                comment.userName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                DateFormatter.formatRelativeDate(comment.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.comment ?? '',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionBar(
      SharedNote note, bool isDark, Color primaryColor) {
    final userId = AuthService.instance.userId ?? '';

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E1E1E).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Réactions emojis
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: Reaction.availableEmojis.map((emoji) {
                    final hasReacted = note.hasReacted(userId, emoji);

                    return GestureDetector(
                      onTap: () => _toggleReaction(note, emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: hasReacted
                              ? primaryColor.withOpacity(0.2)
                              : (isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey.withOpacity(0.05)),
                          borderRadius: BorderRadius.circular(15),
                          border: hasReacted
                              ? Border.all(color: primaryColor, width: 2)
                              : null,
                        ),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Champ de commentaire
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Écrire un commentaire...',
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        maxLines: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSendingComment
                          ? null
                          : () => _sendComment(note.id),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: _isSendingComment
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
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
    );
  }

  Color _getTextColor(Color bg, bool isDark) {
    if (isDark) return Colors.white;
    // Si la couleur est trop claire, texte noir, sinon texte blanc
    return bg.computeLuminance() > 0.6 ? Colors.black87 : Colors.white;
  }
}
