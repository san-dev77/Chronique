import 'dart:typed_data';
import 'dart:ui' show FontFeature;
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/shared_note.dart';
import '../models/reaction.dart';
import '../services/sharing_service.dart';
import '../services/auth_service.dart';
import '../services/image_base64_service.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import '../widgets/rich_text_viewer.dart';

/// Écran pour visualiser une chronique partagée avec réactions et commentaires
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
  bool _chroniqueFinished = false;
  bool _waitingForContinue = false;

  final GlobalKey<RichTextViewerState> _contentViewerKey = GlobalKey();

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

  void _finishChronique() {
    if (mounted) {
      setState(() => _chroniqueFinished = true);
      _finishedController.forward();
    }
  }

  void _skipToEnd() {
    if (mounted) {
      setState(() {
        _showContent = true;
        _chroniqueFinished = true;
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
            title: Row(
              children: [
                UserAvatar(
                  userId: note.senderId,
                  displayName: note.senderName,
                  radius: 12,
                  heroTag: 'avatar_view_${note.id}',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRecipient
                        ? 'De ${note.senderName}'
                        : 'Partagé avec ${note.recipientEmail}',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
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
                      child: GestureDetector(
                        onTap: () {
                          debugPrint(
                              'TAP detected! _waitingForContinue=$_waitingForContinue, key.currentState=${_contentViewerKey.currentState}');
                          if (_waitingForContinue) {
                            setState(() => _waitingForContinue = false);
                            _contentViewerKey.currentState?.continueTyping();
                            debugPrint('Called continueTyping');
                          }
                        },
                        behavior: HitTestBehavior.opaque,
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

                              // 2. TITRE - Rich Text avec Typewriter
                              if (note.title.isNotEmpty && _showContent)
                                RichTextViewer(
                                  key: ValueKey('title_${note.id}'),
                                  content: note.title,
                                  skip: _chroniqueFinished,
                                  baseStyle: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                ),

                              if (note.title.isNotEmpty)
                                const SizedBox(height: 24),

                              // 3. CONTENU - Rich Text avec Typewriter
                              if (note.content.isNotEmpty && _showContent)
                                RichTextViewer(
                                  key: _contentViewerKey,
                                  content: note.content,
                                  formattedContent: note.formattedContent,
                                  skip: _chroniqueFinished,
                                  chunkSize: 300,
                                  baseStyle: TextStyle(
                                    fontSize: 18,
                                    color: textColor.withOpacity(0.9),
                                    height: 1.7,
                                    fontFamily: 'Georgia',
                                  ),
                                  startDelay: const Duration(milliseconds: 800),
                                  onPause: () => setState(
                                      () => _waitingForContinue = true),
                                  onComplete: _finishChronique,
                                ),

                              // Métadonnées
                              const SizedBox(height: 48),
                              _buildMetaBadge(note, textColor),

                              // Terminé
                              if (_chroniqueFinished)
                                _buildFinished(textColor, isDark, primaryColor),

                              const SizedBox(height: 40),
                              _buildReactionsAndComments(
                                  note, isDark, primaryColor),

                              const SizedBox(height: 160),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),

                // Barre de réactions (uniquement destinataire) - MAINTENANT DANS LE STACK
                if (isRecipient)
                  _buildInteractionBar(note, isDark, primaryColor),

                // Bouton Skip
                if (!_chroniqueFinished)
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
    return Builder(builder: (context) {
      // Sans contrainte, Image.memory s'affiche a la resolution intrinseque :
      // une photo de 1920 px occupait toute la colonne sur toute sa hauteur.
      final size = MediaQuery.sizeOf(context);
      final maxH = (size.height * 0.36).clamp(180.0, 380.0);
      final dpr = MediaQuery.devicePixelRatioOf(context);

      final images = <Widget>[];
      for (var i = 0; i < imagesBase64.length; i++) {
        final bytes =
            ImageBase64Service.instance.decodeBase64ToBytes(imagesBase64[i]);
        if (bytes == null) continue;
        images.add(_SharedImage(
          bytes: bytes,
          maxHeight: i == 0 ? maxH : maxH * 0.55,
          dpr: dpr,
        ));
      }
      if (images.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          images.first,
          if (images.length > 1) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: images.skip(1).toList(),
            ),
          ],
        ],
      );
    });
  }

  Widget _buildReactionsAndComments(
      SharedNote note, bool isDark, Color primaryColor) {
    final emojiReactions =
        note.reactions.where((r) => r.isEmojiReaction).toList();
    final comments = note.reactions.where((r) => r.isComment).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    if (emojiReactions.isEmpty && comments.isEmpty) {
      return _EmptyThread(isDark: isDark, accent: primaryColor);
    }

    final grouped = _groupReactionsByEmoji(emojiReactions);
    final me = AuthService.instance.userId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grouped.isNotEmpty) ...[
          _ThreadLabel(
            text: 'Réactions',
            count: emojiReactions.length,
            isDark: isDark,
            accent: primaryColor,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: grouped.entries.map((e) {
              // Une reaction a laquelle on a participe se distingue.
              final mine = emojiReactions.any(
                  (r) => r.emoji == e.key && r.userId == me);
              return _ReactionPill(
                emoji: e.key,
                count: e.value,
                mine: mine,
                isDark: isDark,
                accent: primaryColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
        ],
        if (comments.isNotEmpty) ...[
          _ThreadLabel(
            text: 'Commentaires',
            count: comments.length,
            isDark: isDark,
            accent: primaryColor,
          ),
          const SizedBox(height: 14),
          // Fil de conversation : un filet relie les messages, comme dans une
          // discussion, au lieu d'une pile de cartes independantes.
          for (var i = 0; i < comments.length; i++)
            _CommentTile(
              comment: comments[i],
              isDark: isDark,
              accent: primaryColor,
              isMine: comments[i].userId == me,
              isAuthor: comments[i].userId == note.senderId,
              isLast: i == comments.length - 1,
            ),
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
                    UserAvatar(
                      userId: AuthService.instance.userId,
                      displayName: AuthService.instance.userName ?? '?',
                      radius: 18,
                      heroTag: 'avatar_comment_input',
                    ),
                    const SizedBox(width: 8),
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

/// Image d'une chronique partagee, hauteur bornee et decodee a la bonne taille.
class _SharedImage extends StatefulWidget {
  final Uint8List bytes;
  final double maxHeight;
  final double dpr;

  const _SharedImage({
    required this.bytes,
    required this.maxHeight,
    required this.dpr,
  });

  @override
  State<_SharedImage> createState() => _SharedImageState();
}

class _SharedImageState extends State<_SharedImage> {
  bool _hover = false;

  void _open() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.memory(widget.bytes, fit: BoxFit.contain),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: _open,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hover ? 0.34 : 0.18),
                blurRadius: _hover ? 26 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: LayoutBuilder(
              builder: (context, c) => Image.memory(
                widget.bytes,
                fit: BoxFit.cover,
                width: double.infinity,
                cacheWidth: c.maxWidth.isFinite && c.maxWidth > 0
                    ? (c.maxWidth * widget.dpr).round()
                    : null,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  color: Colors.black26,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.white38),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Intitule d'une section du fil, avec son compte.
class _ThreadLabel extends StatelessWidget {
  final String text;
  final int count;
  final bool isDark;
  final Color accent;

  const _ThreadLabel({
    required this.text,
    required this.count,
    required this.isDark,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            height: 1,
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

/// Pastille de reaction. Celle a laquelle on a participe est cerclee d'accent.
class _ReactionPill extends StatefulWidget {
  final String emoji;
  final int count;
  final bool mine;
  final bool isDark;
  final Color accent;

  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.mine,
    required this.isDark,
    required this.accent,
  });

  @override
  State<_ReactionPill> createState() => _ReactionPillState();
}

class _ReactionPillState extends State<_ReactionPill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..translate(0.0, _hover ? -2.0 : 0.0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: widget.mine
              ? accent.withValues(alpha: widget.isDark ? 0.22 : 0.13)
              : (widget.isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.045)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.mine
                ? accent.withValues(alpha: 0.7)
                : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 7),
            Text(
              '${widget.count}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: widget.mine
                    ? accent
                    : (widget.isDark
                        ? AppTheme.textMutedDark
                        : AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un message du fil : avatar, filet de continuite, bulle.
class _CommentTile extends StatelessWidget {
  final Reaction comment;
  final bool isDark;
  final Color accent;
  final bool isMine;
  final bool isAuthor;
  final bool isLast;

  const _CommentTile({
    required this.comment,
    required this.isDark,
    required this.accent,
    required this.isMine,
    required this.isAuthor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final bubble = isMine
        ? accent.withValues(alpha: isDark ? 0.20 : 0.12)
        : (isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.black.withValues(alpha: 0.035));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              UserAvatar(
                userId: comment.userId,
                displayName: comment.userName,
                radius: 15,
                heroTag: 'avatar_comment_${comment.id}',
              ),
              // Filet de continuite : le fil se lit comme une conversation.
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.08),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          isMine ? 'Vous' : comment.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ),
                      if (isAuthor) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'AUTEUR',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        DateFormatter.formatRelativeDate(comment.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? AppTheme.textMutedDark
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: bubble,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                      border: isMine
                          ? Border.all(color: accent.withValues(alpha: 0.35))
                          : null,
                    ),
                    child: Text(
                      comment.comment ?? '',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.92)
                            : AppTheme.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aucune reaction ni commentaire : on invite plutot que de laisser un vide.
class _EmptyThread extends StatelessWidget {
  final bool isDark;
  final Color accent;

  const _EmptyThread({required this.isDark, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black)
              .withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.mode_comment_outlined,
              size: 26, color: accent.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(
            'Personne n\'a encore réagi',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Soyez le premier à laisser un mot.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
