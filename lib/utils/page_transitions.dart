import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PageTransitions {
  /// Sur iPhone, une page s'ouvre en glissant depuis la droite et se referme
  /// en tirant depuis le bord gauche. Ce geste n'est pas un ornement : c'est
  /// la facon dont on revient en arriere sur iOS, souvent sans regarder.
  ///
  /// Un `PageRouteBuilder` maison, aussi joli soit-il, ne le propose pas :
  /// seul `CupertinoPageRoute` le porte. Nos animations restent donc pour
  /// Android et le bureau, et iOS retrouve son geste.
  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  // Transition de type "slide up" pour l'ouverture des notes
  static Route<dynamic> slideUpTransition(Widget page) {
    // Monter depuis le bas, c'est une feuille modale sur iOS : elle se
    // referme en la tirant vers le bas, comme partout ailleurs sur l'appareil.
    if (_isApple) {
      return CupertinoPageRoute<dynamic>(
        fullscreenDialog: true,
        builder: (_) => page,
      );
    }
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  // Transition de type "fade" pour les changements de thème
  static Route<dynamic> fadeTransition(Widget page) {
    // Le fondu reste : il sert aux changements de theme, pas a la
    // navigation, et aucun geste de retour n'y est attendu.
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation.drive(
            Tween(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: Curves.easeInOut),
            ),
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  // Transition de type "scale" pour l'édition des notes
  static Route<dynamic> scaleTransition(Widget page) {
    if (_isApple) return CupertinoPageRoute<dynamic>(builder: (_) => page);
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.8;
        const end = 1.0;
        const curve = Curves.easeOutBack;

        var scaleAnimation = animation.drive(
          Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          ),
        );

        var fadeAnimation = animation.drive(
          Tween(begin: 0.0, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  // Transition de type "hero" pour les cartes de notes
  static Route<dynamic> heroTransition(Widget page, {String? tag}) {
    if (_isApple) return CupertinoPageRoute<dynamic>(builder: (_) => page);
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.3);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        var offsetAnimation = animation.drive(tween);
        var scaleAnimation = animation.drive(
          Tween(begin: 0.95, end: 1.0).chain(
            CurveTween(curve: Curves.easeOut),
          ),
        );

        return SlideTransition(
          position: offsetAnimation,
          child: ScaleTransition(
            scale: scaleAnimation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 450),
    );
  }
}
