import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_box/models/note.dart';
import 'package:story_box/utils/french_dates.dart';
import 'package:story_box/widgets/search_sheet.dart';

Note _note({
  String titre = '',
  String contenu = '',
  String? citation,
  DateTime? date,
}) {
  final d = date ?? DateTime(2026, 10, 15);
  return Note(
    id: d.microsecondsSinceEpoch.toString(),
    title: titre,
    content: contenu,
    createdAt: d,
    modifiedAt: d,
    imagePaths: const [],
    color: Colors.white,
    isFavorite: false,
    quote: citation,
  );
}

void main() {
  group('Surlignage du terme cherche', () {
    test('isole chaque occurrence', () {
      final bouts = decoupeSurTerme('Marie et Marion', 'mari');

      expect(bouts.map((f) => f.texte).join(), 'Marie et Marion');
      expect(bouts.where((f) => f.correspond).length, 2);
    });

    test('garde la casse d\'origine', () {
      // On cherche « marie » mais on surligne « Marie » : le texte affiche
      // ne doit jamais etre celui de la requete.
      final bouts = decoupeSurTerme('Marie', 'marie');

      final mis = bouts.firstWhere((f) => f.correspond);
      expect(mis.texte, 'Marie');
    });

    test('un terme absent laisse le texte entier', () {
      final bouts = decoupeSurTerme('bonjour', 'zzz');

      expect(bouts.length, 1);
      expect(bouts.single.correspond, isFalse);
      expect(bouts.single.texte, 'bonjour');
    });

    test('un terme vide ne decoupe rien', () {
      // Le champ de recherche vide passe par ici a chaque frappe effacee :
      // sans ce garde, la boucle d'indexOf ne terminait pas.
      final bouts = decoupeSurTerme('bonjour', '');

      expect(bouts.length, 1);
      expect(bouts.single.correspond, isFalse);
    });

    test('un terme en bout de chaine ne perd rien', () {
      final bouts = decoupeSurTerme('abc', 'c');

      expect(bouts.map((f) => f.texte).join(), 'abc');
      expect(bouts.last.correspond, isTrue);
    });
  });

  group('Extrait autour de la trouvaille', () {
    test('cadre sur le terme, pas sur le debut du texte', () {
      // C'est l'interet de la fonction : montrer les premiers mots d'une
      // chronique n'aide pas quand le terme est trois paragraphes plus loin.
      final bourrage = 'lorem ipsum ' * 40;
      final note = _note(contenu: '${bourrage}la pluie sur le toit');

      final extrait = extraitAutourDe(note, 'pluie');

      expect(extrait, contains('pluie'));
      expect(extrait.startsWith('…'), isTrue,
          reason: 'le debut coupe doit etre signale');
    });

    test('ne met pas de points de suspension si rien n\'est coupe', () {
      final note = _note(contenu: 'la pluie sur le toit');

      final extrait = extraitAutourDe(note, 'pluie');

      expect(extrait, 'la pluie sur le toit');
    });

    test('cherche aussi dans la citation', () {
      final note = _note(contenu: 'rien ici', citation: 'le vent se leve');

      expect(extraitAutourDe(note, 'vent'), contains('vent'));
    });

    test('ecrase les retours a la ligne', () {
      // Un extrait sur deux lignes cassait l'alignement des rangees.
      final note = _note(contenu: 'premiere ligne\n\n\nseconde ligne');

      final extrait = extraitAutourDe(note, 'seconde');

      expect(extrait, isNot(contains('\n')));
    });

    test('un terme present seulement dans le titre montre le contenu', () {
      final note = _note(titre: 'Dimanche', contenu: 'il a plu toute la nuit');

      expect(extraitAutourDe(note, 'dimanche'), 'il a plu toute la nuit');
    });

    test('une chronique sans contenu rend une chaine vide', () {
      expect(extraitAutourDe(_note(titre: 'Seul'), 'seul'), '');
    });
  });

  group('Groupement par mois', () {
    test('coupe la ou le mois change', () {
      final notes = [
        _note(date: DateTime(2026, 10, 20)),
        _note(date: DateTime(2026, 10, 2)),
        _note(date: DateTime(2026, 9, 28)),
        _note(date: DateTime(2026, 7, 1)),
      ];

      final groupes = groupeParMois(notes, (n) => n.createdAt);

      expect(groupes.length, 3);
      expect(groupes[0].length, 2);
      expect(groupes[1].length, 1);
      expect(groupes[2].length, 1);
    });

    test('ne perd aucune chronique', () {
      final notes = [
        for (var m = 1; m <= 12; m++)
          for (var j = 1; j <= 3; j++) _note(date: DateTime(2026, m, j)),
      ];

      final groupes = groupeParMois(notes, (n) => n.createdAt);

      expect(groupes.expand((g) => g).length, notes.length);
    });

    test('distingue le meme mois de deux annees', () {
      final notes = [
        _note(date: DateTime(2026, 3, 5)),
        _note(date: DateTime(2025, 3, 5)),
      ];

      expect(groupeParMois(notes, (n) => n.createdAt).length, 2);
    });

    test('une liste vide ne rend aucun groupe', () {
      expect(groupeParMois(<Note>[], (n) => n.createdAt), isEmpty);
    });

    test('ne retrie pas : un desordre reste visible', () {
      // La grille trie en amont. Si ce tri disparaissait un jour, le
      // decoupage doit le montrer plutot que de le rattraper en silence.
      final notes = [
        _note(date: DateTime(2026, 10, 1)),
        _note(date: DateTime(2026, 8, 1)),
        _note(date: DateTime(2026, 10, 2)),
      ];

      expect(groupeParMois(notes, (n) => n.createdAt).length, 3);
    });
  });

  group('Intertitres', () {
    final aujourdhui = DateTime(2026, 10, 29);

    test('le mois courant se nomme par sa distance', () {
      expect(libelleDuMois(DateTime(2026, 10, 3), aujourdhui: aujourdhui),
          'Ce mois-ci');
    });

    test('le mois precedent aussi', () {
      expect(libelleDuMois(DateTime(2026, 9, 3), aujourdhui: aujourdhui),
          'Le mois dernier');
    });

    test('l\'annee est omise dans l\'annee en cours', () {
      expect(libelleDuMois(DateTime(2026, 3, 3), aujourdhui: aujourdhui),
          'Mars');
    });

    test('l\'annee apparait au-dela', () {
      expect(libelleDuMois(DateTime(2025, 3, 3), aujourdhui: aujourdhui),
          'Mars 2025');
    });

    test('un janvier vu depuis fevrier est bien « le mois dernier »', () {
      // Le passage d'annee est le piege classique d'un calcul fait sur le
      // seul numero de mois : 1 - 12 ne vaut pas -1.
      expect(
        libelleDuMois(DateTime(2025, 12, 20),
            aujourdhui: DateTime(2026, 1, 10)),
        'Le mois dernier',
      );
    });
  });
}
