import 'package:flutter/material.dart';

class AppLauncherPreview extends StatelessWidget {
  final double size;
  final bool showBorder;

  const AppLauncherPreview({
    super.key,
    this.size = 80,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.1),
        border: showBorder
            ? Border.all(
                color: Colors.grey.withOpacity(0.3),
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.1),
        child: Padding(
          padding: EdgeInsets.all(
              size * 0.03), // Padding réduit pour l'image plus grande
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.contain, // Utilise contain pour éviter l'étirement
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                Icons.note,
                size: size * 0.6,
                color: Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }
}
