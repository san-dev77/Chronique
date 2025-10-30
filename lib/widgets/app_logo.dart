import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final bool showBorder;
  final double borderRadius;

  const AppLogo({
    super.key,
    this.size = 40,
    this.backgroundColor,
    this.showBorder = false,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white, // Fond blanc fixe
        borderRadius: BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Padding(
          padding: EdgeInsets.all(
              size * 0.03), // Padding réduit pour l'image plus grande
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain, // Utilise contain pour éviter la déformation
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.note,
                size: size * 0.6,
                color: Theme.of(context).colorScheme.primary,
              );
            },
          ),
        ),
      ),
    );
  }
}
