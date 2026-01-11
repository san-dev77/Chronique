import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ColorPicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: AppTheme.noteColors.length,
      itemBuilder: (context, index) {
        final color = AppTheme.noteColors[index];
        final isSelected = selectedColor.value == color.value;
        final isWhite = color == Colors.white || color.value == 0xFFFFFFFF;

        return GestureDetector(
          onTap: () => onColorChanged(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? AppTheme.skyBlue
                    : (isWhite ? Colors.grey.shade300 : color.withOpacity(0.5)),
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppTheme.skyBlue.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    color: color.computeLuminance() > 0.5
                        ? AppTheme.textDark
                        : Colors.white,
                    size: 24,
                  )
                : null,
          ),
        );
      },
    );
  }
}
