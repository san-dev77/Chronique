// Les periodes de souvenirs.
//
// Ces tests existent a cause d'un defaut precis : la selection parcourait les
// periodes dans l'ordre et s'arretait a la premiere qui trouvait une note.
// Comme la liste commence par les plus proches et qu'un journal tenu
// regulierement a toujours une note de deux semaines, « il y a trois mois »
// n'arrivait jamais.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:story_box/models/note.dart';
import 'package:story_box/services/memory_periods.dart';

final _now = DateTime(2026, 10, 20, 12);

Note _noteAgedDays(int days, {String id = 'n'}) {
  final created = _now.subtract(Duration(days: days));
  return Note(
    id: '$id-$days',
    title: 'Chronique de $days jours',
    content: '',
    createdAt: created,
    modifiedAt: created,
    color: Colors.white,
  );
}

void main() {
  group('Une periode reconnait les chroniques de son age', () {
    test('trois mois accepte une note de 90 jours', () {
      final period = MemoryPeriod.byDays(90)!;
      expect(period.matching([_noteAgedDays(90)], now: _now), hasLength(1));
    });

    test('trois mois tolere quelques jours d ecart', () {
      final period = MemoryPeriod.byDays(90)!;
      expect(period.matching([_noteAgedDays(93)], now: _now), hasLength(1));
      expect(period.matching([_noteAgedDays(87)], now: _now), hasLength(1));
      expect(period.matching([_noteAgedDays(80)], now: _now), isEmpty);
    });

    test('la marge s elargit avec la distance', () {
      // A une semaine, un jour d ecart compte. A un an, non.
      expect(MemoryPeriod.byDays(7)!.tolerance, 1);
      expect(MemoryPeriod.byDays(365)!.tolerance, 7);
      expect(
        MemoryPeriod.byDays(365)!.matching([_noteAgedDays(371)], now: _now),
        hasLength(1),
      );
    });

    test('une note ne tombe pas dans la mauvaise periode', () {
      final notes = [_noteAgedDays(90)];
      expect(MemoryPeriod.byDays(30)!.matching(notes, now: _now), isEmpty);
      expect(MemoryPeriod.byDays(180)!.matching(notes, now: _now), isEmpty);
    });
  });

  group('Les periodes disponibles', () {
    test('ne retiennent que celles qui ont quelque chose a montrer', () {
      final notes = [
        _noteAgedDays(7),
        _noteAgedDays(90),
        _noteAgedDays(365),
        _noteAgedDays(500), // ne correspond a aucune periode
      ];

      final available = MemoryPeriod.available(notes, now: _now)
          .map((p) => p.days)
          .toList();

      expect(available, containsAll([7, 90, 365]));
      expect(available, isNot(contains(14)));
      expect(available, isNot(contains(30)));
    });

    test('les lointaines sont la quand elles existent', () {
      // Le defaut d origine : avec une note de deux semaines ET une de trois
      // mois, seule la premiere etait jamais proposee. Les deux doivent
      // desormais figurer parmi les choix possibles.
      final notes = [_noteAgedDays(14), _noteAgedDays(90)];
      final available = MemoryPeriod.available(notes, now: _now)
          .map((p) => p.days)
          .toList();

      expect(available, [14, 90]);
    });

    test('aucune periode quand rien ne correspond', () {
      expect(
        MemoryPeriod.available([_noteAgedDays(50)], now: _now),
        isEmpty,
      );
    });
  });

  group('Le catalogue', () {
    test('couvre d une semaine a trois ans', () {
      final days = MemoryPeriod.all.map((p) => p.days).toList();
      expect(days, [7, 14, 30, 90, 180, 365, 730, 1095]);
    });

    test('chaque periode porte une formule et un titre', () {
      for (final period in MemoryPeriod.all) {
        expect(period.label, isNotEmpty);
        expect(period.title, isNotEmpty);
        expect(period.label, startsWith('Il y a '));
      }
    });
  });
}
