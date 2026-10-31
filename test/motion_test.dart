import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_box/widgets/motion.dart';

Widget _cadre(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Opacité appliquée **par le Reveal**, et non par un widget quelconque de
/// l'arbre : un chercheur non cadré rendait certains tests concluants par
/// accident.
double _opacite(WidgetTester tester) {
  final f = find.descendant(
    of: find.byType(Reveal),
    matching: find.byType(Opacity),
  );
  return tester.widget<Opacity>(f.first).opacity;
}

/// Décalage vertical appliqué par [T] (Reveal ou Parallax).
double _decalageY<T extends Widget>(WidgetTester tester) {
  final f = find.descendant(
    of: find.byType(T),
    matching: find.byType(Transform),
  );
  return tester.widget<Transform>(f.first).transform.getTranslation().y;
}

void main() {
  group('Retard de cascade', () {
    test('croit avec le rang', () {
      expect(RevealMotion.retardPour(0), Duration.zero);
      expect(RevealMotion.retardPour(2), RevealMotion.pas * 2);
    });

    test('est borne pour que la fin de liste n\'attende pas', () {
      // Sans borne, la trentieme carte arrivait une seconde et demie apres
      // la premiere : la grille paraissait lente a charger.
      expect(RevealMotion.retardPour(200), RevealMotion.retardMax);
      expect(
        RevealMotion.retardPour(200),
        lessThanOrEqualTo(const Duration(milliseconds: 500)),
      );
    });
  });

  group('Reveal', () {
    testWidgets('part transparent et decale, puis se pose', (tester) async {
      await tester.pumpWidget(_cadre(const Reveal(child: Text('bonjour'))));

      expect(_opacite(tester), 0);
      expect(_decalageY<Reveal>(tester), RevealMotion.montee);

      await tester.pumpAndSettle();

      expect(_opacite(tester), 1);
      expect(_decalageY<Reveal>(tester), 0);
    });

    testWidgets('animate: false affiche tout de suite', (tester) async {
      // C'est le chemin pris par une carte deja vue : elle doit etre
      // entiere des la premiere image, sans clignoter.
      await tester.pumpWidget(
        _cadre(const Reveal(animate: false, child: Text('bonjour'))),
      );

      expect(_opacite(tester), 1);
      expect(_decalageY<Reveal>(tester), 0);
    });

    testWidgets('un rang eleve retarde le depart', (tester) async {
      await tester.pumpWidget(
        _cadre(const Reveal(index: 4, child: Text('bonjour'))),
      );

      // Le retard court toujours : rien n'a encore bouge.
      await tester.pump(const Duration(milliseconds: 40));
      expect(_opacite(tester), 0);

      // pumpAndSettle ne fait pas avancer un Future.delayed : sans image
      // programmee il rend la main aussitot. On franchit donc le retard a
      // la main avant de laisser l'animation se jouer.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(_opacite(tester), 1);
    });

    testWidgets('se demonte pendant son retard sans exploser', (tester) async {
      // Le defilement rapide detruit des cartes avant la fin de leur
      // attente : le Future.delayed se reveille alors sur un State mort.
      await tester.pumpWidget(
        _cadre(const Reveal(index: 6, child: Text('bonjour'))),
      );
      await tester.pumpWidget(_cadre(const SizedBox()));
      await tester.pump(const Duration(milliseconds: 600));

      expect(tester.takeException(), isNull);
    });

    testWidgets('respecte « reduire les animations »', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _cadre(const Reveal(child: Text('bonjour'))),
        ),
      );
      await tester.pump();

      expect(_opacite(tester), 1);
    });
  });

  group('PressScale', () {
    testWidgets('s\'enfonce a l\'appui et se releve', (tester) async {
      await tester.pumpWidget(
        _cadre(const PressScale(
          child: ColoredBox(
            color: Colors.blue,
            child: SizedBox(width: 100, height: 100),
          ),
        )),
      );

      double echelle() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

      expect(echelle(), 1);

      final geste = await tester.startGesture(tester.getCenter(
        find.byType(SizedBox).first,
      ));
      await tester.pump();
      expect(echelle(), lessThan(1));

      await geste.up();
      await tester.pump();
      expect(echelle(), 1);
    });

    testWidgets('transmet le clic', (tester) async {
      var touche = 0;
      await tester.pumpWidget(_cadre(PressScale(
        onTap: () => touche++,
        child: const ColoredBox(
          color: Colors.blue,
          child: SizedBox(width: 100, height: 100),
        ),
      )));

      await tester.tap(find.byType(SizedBox).first);
      expect(touche, 1);
    });
  });

  group('Parallax', () {
    Widget page(ScrollController c) => _cadre(
          ListView(
            controller: c,
            children: [
              Parallax(
                controller: c,
                // Haut expres : le plafond de 60 px est atteint des 200 px de
                // defilement, et l'enfant doit encore etre monte pour
                // qu'on puisse l'observer.
                child: const SizedBox(height: 900, width: 200),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        );

    testWidgets('decale l\'image a mesure du defilement', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);

      await tester.pumpWidget(page(c));
      expect(_decalageY<Parallax>(tester), 0);

      c.jumpTo(100);
      await tester.pump();

      // Facteur 0,3 : cent pixels de defilement en deplacent trente.
      expect(_decalageY<Parallax>(tester), closeTo(30, 0.01));
    });

    testWidgets('ne depasse jamais son maximum', (tester) async {
      // Sans borne, l'image finissait par sortir de son cadre et laissait
      // une bande vide en haut de la page.
      final c = ScrollController();
      addTearDown(c.dispose);

      await tester.pumpWidget(page(c));
      c.jumpTo(400);
      await tester.pump();

      expect(_decalageY<Parallax>(tester), 60);
    });

    testWidgets('ignore le rebond vers le haut', (tester) async {
      final c = ScrollController();
      addTearDown(c.dispose);

      await tester.pumpWidget(page(c));
      c.jumpTo(-80);
      await tester.pump();

      expect(_decalageY<Parallax>(tester), 0);
    });
  });
}
