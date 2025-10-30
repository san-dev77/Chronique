import 'package:flutter/material.dart';

class AppLauncherIcon extends StatelessWidget {
  final double size;
  final Color backgroundColor;

  const AppLauncherIcon({
    super.key,
    this.size = 40,
    this.backgroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(size * 0.1), // Très légèrement arrondi
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
