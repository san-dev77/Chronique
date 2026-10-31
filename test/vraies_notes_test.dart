@Tags(['donnees-locales'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:story_box/models/note.dart';
import 'package:story_box/utils/french_dates.dart';

/// Fait tourner le découpage réel sur les vraies chroniques.
///
/// Un intertitre de mois se répétait « en boucle » sur le téléphone, alors
/// que la logique passe tous les tests synthétiques. Plutôt que de deviner,
/// on rejoue le calcul sur les données elles-mêmes — une copie de la boîte
/// Hive, jamais l'originale.
///
/// Le test se passe de données s'il n'en trouve pas : il ne doit pas casser
/// l'intégration pour qui n'a pas cette boîte sous la main.
void main() {
  final dossier = Platform.environment['CHRONIQUES_HIVE'] ??
      r'C:\Users\Dell\AppData\Local\Temp\claude'
          r'\C--Users-Dell-OneDrive-Bureau-APP-note-keeper'
          r'\e72eb77f-67d3-4ba0-8629-8a490265f71f\scratchpad\hivecopie';

  const nomBoite = 'notes_jfeuy6ryj3gpigzqcw7theyfyai2';

  test('les intertitres ne se repetent pas sur les vraies chroniques',
      () async {
    final fichier = File('$dossier${Platform.pathSeparator}$nomBoite.hive');
    if (!fichier.existsSync()) {
      markTestSkipped('boite absente : $fichier');
      return;
    }

    Hive.init(dossier);
    final boite = await Hive.openBox(nomBoite);
    addTearDown(() async {
      await boite.close();
      await Hive.close();
    });

    // Meme chemin que NoteService : les notes sont des Map JSON.
    final notes = <Note>[];
    var illisibles = 0;
    for (final brut in boite.values) {
      try {
        notes.add(Note.fromJson(Map<String, dynamic>.from(brut as Map)));
      } catch (_) {
        illisibles++;
      }
    }

    print('notes lues : ${notes.length}  (illisibles : $illisibles)');
    expect(notes, isNotEmpty, reason: 'la boite doit contenir des notes');

    // Exactement ce que fait l'ecran : tri decroissant, puis decoupage.
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final groupes = groupeParMois(notes, (n) => n.createdAt);

    final libelles = <String>[];
    for (final g in groupes) {
      final l = libelleDuMois(g.first.createdAt);
      libelles.add(l);
      print('  $l  — ${g.length} chroniques  '
          '(${g.first.createdAt.year}-${g.first.createdAt.month})');
    }

    // Le defaut rapporte, formule en assertion : aucun intertitre ne doit
    // apparaitre deux fois dans la colonne.
    final doublons = <String>{};
    final vus = <String>{};
    for (final l in libelles) {
      if (!vus.add(l)) doublons.add(l);
    }

    expect(doublons, isEmpty,
        reason: 'intertitres repetes : ${doublons.join(", ")}');
  });
}
