import 'package:flutter/material.dart';

/// Logo réutilisable de l'app (depuis assets)
class NoteLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const NoteLogo({
    super.key,
    this.size = 140,
    this.showShadow = true,
    this.isRound = false,
  });

  final bool isRound;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isRound ? size / 2 : size * 0.2),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: size * 0.2,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isRound ? size / 2 : size * 0.2),
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
