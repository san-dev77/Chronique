import 'package:flutter/material.dart';

class AppIcon extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final bool showBorder;
  final bool forceSquare;

  const AppIcon({
    super.key,
    this.size = 40,
    this.backgroundColor,
    this.showBorder = false,
    this.forceSquare = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: showBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.2),
        child: forceSquare
            ? Image.asset(
                'assets/logo.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.note,
                    size: size * 0.6,
                    color: Colors.white,
                  );
                },
              )
            : Image.asset(
                'assets/logo.jpeg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.note,
                    size: size * 0.6,
                    color: Colors.white,
                  );
                },
              ),
      ),
    );
  }
}
