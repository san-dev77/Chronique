import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Barre d'outils de formatage qui apparaît lors de la sélection de texte
class FormattingToolbar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onQuote;
  final ValueChanged<Color> onTextColor;
  final ValueChanged<Color> onBackgroundColor;
  final bool isBoldActive;
  final bool isItalicActive;
  final bool isQuoteActive;

  const FormattingToolbar({
    super.key,
    required this.onBold,
    required this.onItalic,
    required this.onQuote,
    required this.onTextColor,
    required this.onBackgroundColor,
    this.isBoldActive = false,
    this.isItalicActive = false,
    this.isQuoteActive = false,
  });

  static const _textColors = [
    Colors.black,
    Colors.white,
    Color(0xFFE53935), // Rouge
    Color(0xFFFF9800), // Orange
    Color(0xFFFFC107), // Jaune
    Color(0xFF4CAF50), // Vert
    Color(0xFF2196F3), // Bleu
    Color(0xFF9C27B0), // Violet
  ];

  static const _bgColors = [
    Color(0xFFFFEB3B), // Jaune fluo
    Color(0xFF80DEEA), // Cyan clair
    Color(0xFFA5D6A7), // Vert clair
    Color(0xFFFFAB91), // Corail
    Color(0xFFCE93D8), // Lavande
    Color(0xFFB0BEC5), // Gris
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF2D2D2D) : Colors.white).withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
          // Bold
          _FormatButton(
            icon: Icons.format_bold_rounded,
            isActive: isBoldActive,
            onTap: onBold,
            tooltip: 'Gras',
          ),
          const SizedBox(width: 4),
          
          // Italic
          _FormatButton(
            icon: Icons.format_italic_rounded,
            isActive: isItalicActive,
            onTap: onItalic,
            tooltip: 'Italique',
          ),
          const SizedBox(width: 4),
          
          // Quote
          _FormatButton(
            icon: Icons.format_quote_rounded,
            isActive: isQuoteActive,
            onTap: onQuote,
            tooltip: 'Citation',
          ),
          
          _buildDivider(isDark),
          
          // Text Color
          _ColorPickerButton(
            icon: Icons.format_color_text_rounded,
            colors: _textColors,
            onColorSelected: onTextColor,
            tooltip: 'Couleur du texte',
          ),
          const SizedBox(width: 4),
          
          // Background Color
          _ColorPickerButton(
            icon: Icons.format_color_fill_rounded,
            colors: _bgColors,
            onColorSelected: onBackgroundColor,
            tooltip: 'Surbrillance',
          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 1,
      height: 24,
      color: isDark ? Colors.white24 : Colors.black12,
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  const _FormatButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.skyBlue.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive
                ? AppTheme.skyBlue
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _ColorPickerButton extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final ValueChanged<Color> onColorSelected;
  final String tooltip;

  const _ColorPickerButton({
    required this.icon,
    required this.colors,
    required this.onColorSelected,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tooltip,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((color) {
                return GestureDetector(
                  onTap: () {
                    onColorSelected(color);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
