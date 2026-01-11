import 'package:flutter/material.dart';

class NoteToolbar extends StatelessWidget {
  final VoidCallback onColorPicker;
  final VoidCallback onAddImage;
  final VoidCallback onSave;
  final bool isAddingImage;
  final bool isCompact;

  const NoteToolbar({
    super.key,
    required this.onColorPicker,
    required this.onAddImage,
    required this.onSave,
    required this.isAddingImage,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      // Version compacte (juste les icônes)
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactButton(
              icon: Icons.palette_outlined,
              onTap: onColorPicker,
            ),
            const SizedBox(width: 8),
            _CompactButton(
              icon: isAddingImage ? null : Icons.image_outlined,
              onTap: isAddingImage ? null : onAddImage,
              isLoading: isAddingImage,
            ),
            const SizedBox(width: 8),
            _CompactButton(
              icon: Icons.check_circle,
              onTap: onSave,
              isPrimary: true,
            ),
          ],
        ),
      );
    }

    // Version normale (avec labels)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolbarButton(
            icon: Icons.palette_outlined,
            onTap: onColorPicker,
            label: 'Couleur',
          ),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.grey.shade200,
          ),
          _ToolbarButton(
            icon: isAddingImage ? null : Icons.image_outlined,
            onTap: isAddingImage ? null : onAddImage,
            isLoading: isAddingImage,
            label: 'Image',
          ),
          Container(
            width: 1,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: Colors.grey.shade200,
          ),
          _ToolbarButton(
            icon: Icons.check_circle,
            onTap: onSave,
            label: 'Terminé',
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final String label;
  final bool isPrimary;

  const _ToolbarButton({
    this.icon,
    this.onTap,
    this.isLoading = false,
    required this.label,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrimary
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(
                  icon,
                  size: 22,
                  color: color,
                ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Bouton compact (sans texte)
class _CompactButton extends StatelessWidget {
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isPrimary;

  const _CompactButton({
    this.icon,
    this.onTap,
    this.isLoading = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPrimary
        ? Theme.of(context).colorScheme.primary
        : Colors.grey.shade700;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(
                  icon,
                  size: 20,
                  color: color,
                ),
        ),
      ),
    );
  }
}

