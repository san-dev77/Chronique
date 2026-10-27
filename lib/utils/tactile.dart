import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Retours tactiles.
///
/// L'iPhone a un moteur haptique precis : une pression bien placee se sent
/// comme un declic mecanique, et c'est une bonne part de ce qui distingue
/// une application soignee d'une application portee. Android les rend aussi,
/// en plus sourd. Sur bureau il n'y a rien a vibrer : les appels n'y font
/// rien plutot que de lever une erreur de greffon a chaque clic.
///
/// Trois intensites suffisent, et s'en tenir a trois garde le vocabulaire
/// lisible : on reconnait un choix, une ouverture, un aboutissement.
class Tactile {
  const Tactile._();

  static bool get _enabled =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android;

  /// Un choix parmi d'autres : onglet, filtre, teinte.
  static void selection() {
    if (_enabled) HapticFeedback.selectionClick();
  }

  /// Une bascule qui change l'etat d'une chose : epingle, favori.
  static void toggle() {
    if (_enabled) HapticFeedback.lightImpact();
  }

  /// Un aboutissement : enregistrement, suppression confirmee.
  static void done() {
    if (_enabled) HapticFeedback.mediumImpact();
  }
}
