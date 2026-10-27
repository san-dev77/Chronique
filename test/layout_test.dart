// Tests de mise en page des surfaces de lecture.
//
// Ils existent a cause d'une panne reelle : un filet vertical pose devant les
// citations reclamait la hauteur de son voisin (`CrossAxisAlignment.stretch`)
// dans une colonne qui n'en imposait aucune. La contrainte devenait infinie,
// la carte echouait a se mettre en page, et plus aucune chronique ne
// s'affichait.
//
// Lancer l'application ne l'avait pas revele : le demarrage n'atteignait pas
// la grille. Ces tests montent les widgets pour de bon, a plusieurs largeurs,
// et echouent si une contrainte derape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:story_box/models/note.dart';
import 'package:story_box/models/note_mood.dart';
import 'package:story_box/widgets/note_card.dart';
import 'package:story_box/widgets/reading_chrome.dart';

Note _note({
  String title = 'Un titre de chronique',
  String content = 'Quelques lignes de contenu pour remplir la carte.',
  String? quote,
  bool favorite = false,
  bool pinned = false,
  String? mood,
}) {
  final now = DateTime(2026, 10, 20);
  return Note(
    id: 'note-test',
    title: title,
    content: content,
    quote: quote,
    createdAt: now,
    modifiedAt: now,
    isFavorite: favorite,
    isPinned: pinned,
    mood: mood,
    moodColor: mood == null ? null : NoteMood.palette.first.toARGB32(),
  );
}

/// Monte un widget dans une colonne de largeur donnee, comme dans la grille.
Future<void> _pumpInColumn(WidgetTester tester, Widget child,
    {double width = 320}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          // La colonne ne borne pas la hauteur : c'est precisement le
          // contexte ou la panne se produisait.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [child],
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('NoteCard se met en page', () {
    testWidgets('avec une citation', (tester) async {
      await _pumpInColumn(
        tester,
        NoteCard(note: _note(quote: 'Une phrase gardee.'), onTap: () {}),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Une phrase gardee.'), findsOneWidget);
    });

    testWidgets('avec une citation et sans titre', (tester) async {
      await _pumpInColumn(
        tester,
        NoteCard(
          note: _note(title: '', content: '', quote: 'Seule la phrase reste.'),
          onTap: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('avec une aura et un favori', (tester) async {
      await _pumpInColumn(
        tester,
        NoteCard(
          note: _note(quote: 'Avec aura.', favorite: true, mood: 'serein'),
          onTap: () {},
          onFavoriteToggle: () {},
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dans une colonne etroite', (tester) async {
      await _pumpInColumn(
        tester,
        NoteCard(
          note: _note(quote: 'Une citation un peu plus longue que la normale.'),
          onTap: () {},
        ),
        width: 180,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('avec une aura au nom long, dans une colonne etroite',
        (tester) async {
      // Le pied de carte porte la date et l'etiquette d'aura. Un nom long
      // les faisait deborder : l'etiquette doit se raccourcir, pas pousser.
      await _pumpInColumn(
        tester,
        NoteCard(
          note: _note(mood: 'vague_a_lame', favorite: true),
          onTap: () {},
          onFavoriteToggle: () {},
        ),
        width: 170,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('avec une citation epinglee', (tester) async {
      // L'epingle se glisse devant la phrase : elle ne doit pas la pousser
      // hors de la carte.
      await _pumpInColumn(
        tester,
        NoteCard(
          note: _note(
            title: '',
            content: '',
            quote: 'Une phrase que je veux garder sous la main.',
            pinned: true,
          ),
          onTap: () {},
          onFavoriteToggle: () {},
        ),
        width: 170,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('sans rien du tout', (tester) async {
      await _pumpInColumn(
        tester,
        NoteCard(note: _note(title: '', content: ''), onTap: () {}),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Les pieces de lecture se mettent en page', () {
    testWidgets('la barre de progression', (tester) async {
      await _pumpInColumn(
        tester,
        const ReadingProgress(value: 0.42, accent: Colors.blue),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('une etiquette de contexte', (tester) async {
      await _pumpInColumn(
        tester,
        const MetaPill(
          icon: Icons.schedule_rounded,
          label: '4 min de lecture',
          textColor: Colors.black,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('4 min de lecture'), findsOneWidget);
    });

    testWidgets('un bouton d outil', (tester) async {
      var tapped = false;
      await _pumpInColumn(
        tester,
        ToolButton(
          icon: Icons.copy_rounded,
          tooltip: 'Copier',
          color: Colors.black,
          onTap: () => tapped = true,
        ),
      );
      await tester.tap(find.byType(ToolButton));
      expect(tapped, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('La duree de lecture', () {
    test('ne descend jamais sous une minute', () {
      expect(readingMinutes('trois mots seulement'), 1);
      expect(readingMinutes(''), 1);
    });

    test('compte deux cents mots par minute', () {
      expect(readingMinutes(List.filled(400, 'mot').join(' ')), 2);
      expect(readingMinutes(List.filled(401, 'mot').join(' ')), 3);
    });
  });
}
