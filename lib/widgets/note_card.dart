import 'package:flutter/material.dart';
import 'dart:io';
import '../models/note.dart';
import '../utils/date_formatter.dart';

class NoteCard extends StatefulWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fonction pour déterminer si une couleur est claire ou sombre
  bool _isLightColor(Color color) {
    double luminance =
        (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5;
  }

  // Fonction pour obtenir une couleur de texte contrastée
  Color _getContrastTextColor(Color backgroundColor) {
    if (_isLightColor(backgroundColor)) {
      return Colors.black87;
    } else {
      return Colors.white;
    }
  }

  // Fonction pour obtenir une couleur de texte secondaire contrastée
  Color _getSecondaryTextColor(Color backgroundColor) {
    if (_isLightColor(backgroundColor)) {
      return Colors.black54;
    } else {
      return Colors.white70;
    }
  }

  void _onHover(bool isHovered) {
    setState(() {
      _isHovered = isHovered;
    });
    if (isHovered) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getContrastTextColor(widget.note.color);
    final secondaryTextColor = _getSecondaryTextColor(widget.note.color);

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: GestureDetector(
              onTap: widget.onTap,
              onLongPress: widget.onLongPress,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: _isHovered ? 20 : 15,
                      offset: Offset(0, _isHovered ? 8 : 6),
                      spreadRadius: _isHovered ? 2 : 1,
                    ),
                    BoxShadow(
                      color: widget.note.color.withOpacity(0.3),
                      blurRadius: _isHovered ? 25 : 20,
                      offset: Offset(0, _isHovered ? 12 : 8),
                      spreadRadius: _isHovered ? 3 : 2,
                    ),
                  ],
                ),
                child: Card(
                  color: widget.note.color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    children: [
                      // Image en arrière-plan si disponible
                      if (widget.note.imagePaths.isNotEmpty)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(
                              File(widget.note.imagePaths.first),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                      // Overlay semi-transparent pour améliorer la lisibilité
                      if (widget.note.imagePaths.isNotEmpty)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.7),
                                ],
                                stops: [0.0, 0.6, 1.0],
                              ),
                            ),
                          ),
                        ),

                      // Contenu principal
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // En-tête avec titre et badge de favori
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: widget.note.title.isNotEmpty
                                      ? Text(
                                          widget.note.title,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                            color: widget
                                                    .note.imagePaths.isNotEmpty
                                                ? Colors.white
                                                : textColor,
                                            letterSpacing: 0.5,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Container(
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: (widget.note.imagePaths
                                                        .isNotEmpty
                                                    ? Colors.white
                                                    : secondaryTextColor)
                                                .withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                ),
                                if (widget.onFavoriteToggle != null)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: widget.note.isFavorite
                                          ? Colors.red
                                          : (widget.note.imagePaths.isNotEmpty
                                                  ? Colors.white
                                                  : secondaryTextColor)
                                              .withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: widget.note.isFavorite
                                            ? Colors.red
                                            : (widget.note.imagePaths.isNotEmpty
                                                    ? Colors.white
                                                    : secondaryTextColor)
                                                .withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: widget.onFavoriteToggle,
                                      icon: Icon(
                                        widget.note.isFavorite
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: widget.note.isFavorite
                                            ? Colors.white
                                            : (widget.note.imagePaths.isNotEmpty
                                                ? Colors.white
                                                : secondaryTextColor),
                                        size: 20,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      constraints: const BoxConstraints(
                                        minWidth: 36,
                                        minHeight: 36,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            // Espacement conditionnel
                            if (widget.note.title.isNotEmpty &&
                                widget.note.content.isNotEmpty)
                              const SizedBox(height: 12),

                            // Contenu de la note
                            if (widget.note.content.isNotEmpty)
                              Expanded(
                                child: Text(
                                  widget.note.content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: widget.note.imagePaths.isNotEmpty
                                        ? Colors.white.withOpacity(0.9)
                                        : textColor,
                                    height: 1.4,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  maxLines: 6,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),

                            // Indicateur d'image si pas d'image en arrière-plan
                            if (widget.note.imagePaths.isNotEmpty &&
                                widget.note.imagePaths.length > 1)
                              Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '+${widget.note.imagePaths.length - 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Pied de carte avec date
                            Container(
                              margin: const EdgeInsets.only(top: 16),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (widget.note.imagePaths.isNotEmpty
                                        ? Colors.white
                                        : secondaryTextColor)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: (widget.note.imagePaths.isNotEmpty
                                          ? Colors.white
                                          : secondaryTextColor)
                                      .withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: widget.note.imagePaths.isNotEmpty
                                        ? Colors.white.withOpacity(0.8)
                                        : secondaryTextColor,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormatter.formatRelativeDate(
                                        widget.note.modifiedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.note.imagePaths.isNotEmpty
                                          ? Colors.white.withOpacity(0.8)
                                          : secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Badge de favori flottant
                      if (widget.note.isFavorite)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
