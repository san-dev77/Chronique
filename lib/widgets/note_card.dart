import 'package:flutter/material.dart';
import 'dart:io';
import '../models/note.dart';
import '../utils/date_formatter.dart';
import '../theme/app_theme.dart';

class NoteCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final hasImage = note.imagePaths.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.cardDark : note.color;
    final isWhite = note.color == Colors.white;
    final textColor = _getTextColor(cardColor, hasImage, isDark);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
              child: Container(
                decoration: BoxDecoration(
          color: hasImage ? null : cardColor,
          borderRadius: BorderRadius.circular(22),
          border: isWhite && !isDark && !hasImage
              ? Border.all(color: Colors.grey.shade200)
              : null,
                  boxShadow: [
                    BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.3)
                  : AppTheme.skyBlue.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
                    ),
                  ],
                ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
              // Image
              if (hasImage) ...[
                        Positioned.fill(
                            child: Image.file(
                    File(note.imagePaths.first),
                              fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: cardColor),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                          Colors.black.withOpacity(0.65),
                                ],
                        stops: const [0.35, 1.0],
                              ),
                            ),
                          ),
                        ),
              ],

              // Contenu
                      Padding(
                padding: const EdgeInsets.all(16),
                        child: Column(
                  mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    // Badges
                    _buildBadges(hasImage),

                    // Titre
                    if (note.title.isNotEmpty) ...[
                      if (note.isFavorite ||
                          (hasImage && note.imagePaths.length > 1))
                        const SizedBox(height: 10),
                      Text(
                        note.title,
                                          style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                                            height: 1.3,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Contenu
                    if (note.content.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        note.content,
                        style: TextStyle(
                          fontSize: 13,
                          color: textColor.withOpacity(0.75),
                          height: 1.45,
                                      ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Date
                    const SizedBox(height: 12),
                    _buildDate(textColor, hasImage),
                  ],
                                    ),
                                  ),
                              ],
                            ),
        ),
      ),
    );
  }

  Widget _buildBadges(bool hasImage) {
    if (!note.isFavorite && !(hasImage && note.imagePaths.length > 1)) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (note.isFavorite)
                              Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
              color: AppTheme.skyBlue,
              borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.favorite_rounded, color: Colors.white, size: 12),
                SizedBox(width: 3),
                Text('Favori',
                    style: TextStyle(
                                      color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
        const Spacer(),
        if (hasImage && note.imagePaths.length > 1)
                            Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                const Icon(Icons.photo_library_rounded,
                    color: Colors.white, size: 12),
                const SizedBox(width: 3),
                Text('${note.imagePaths.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ],
    );
  }

  Widget _buildDate(Color textColor, bool hasImage) {
    return Row(
      children: [
        Icon(Icons.schedule_rounded,
            size: 12, color: textColor.withOpacity(0.5)),
        const SizedBox(width: 4),
        Text(
          DateFormatter.formatRelativeDate(note.modifiedAt),
          style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.5),
              fontWeight: FontWeight.w500),
                                ),
                              ],
    );
  }

  Color _getTextColor(Color bg, bool hasImage, bool isDark) {
    if (hasImage) return Colors.white;
    if (isDark) return AppTheme.textLight;
    return bg.computeLuminance() > 0.5 ? AppTheme.textDark : Colors.white;
  }
}
