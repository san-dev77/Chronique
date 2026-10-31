import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Les intertitres de mois se répétaient « encore et encore » au défilement :
/// on revenait sur le mois courant, puis le mois dernier, puis de nouveau le
/// mois courant.
///
/// Une première version de ce fichier comptait les en-têtes **présents dans
/// l'arbre** et concluait que tout allait bien. C'était le mauvais critère :
/// des slivers qui se chevauchent existent chacun une fois, et seule leur
/// *position* trahit le défaut. On mesure donc des coordonnées.
void main() {
  /// Distribution réelle : 148 chroniques sur quinze mois.
  const mois = [11, 8, 13, 5, 4, 7, 11, 13, 17, 11, 10, 10, 10, 13, 5];

  List<Widget> sections(List<int> tailles) {
    return [
      for (var g = 0; g < tailles.length; g++) ...[
        SliverToBoxAdapter(
          child: SizedBox(height: 40, child: Text('entete-$g')),
        ),
        SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childCount: tailles[g],
          itemBuilder: (_, i) => SizedBox(
            height: 110 + (i % 4) * 35,
            child: Text('carte-$g-$i'),
          ),
        ),
      ],
    ];
  }

  /// Deux dispositions à comparer : l'une regroupe les sections dans un
  /// `SliverMainAxisGroup`, l'autre les pose directement dans la liste de
  /// slivers.
  Widget page(List<int> tailles, {required bool groupe}) {
    final s = sections(tailles);
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: groupe ? [SliverMainAxisGroup(slivers: s)] : s,
        ),
      ),
    );
  }

  /// Vérifie qu'en remontant la liste, les en-têtes visibles apparaissent
  /// dans l'ordre croissant de leur rang.
  ///
  /// Un en-tête d'un mois ancien qui réapparaît au-dessus d'un mois récent
  /// est exactement le symptôme décrit.
  Future<void> verifierOrdre(WidgetTester tester, {required bool groupe}) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(page(mois, groupe: groupe));
    await tester.pumpAndSettle();

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;

    for (var offset = 0.0; offset < 7000; offset += 180) {
      position.jumpTo(offset);
      await tester.pump();

      // Les en-têtes effectivement à l'écran, avec leur ordonnée.
      final vus = <int, double>{};
      for (var g = 0; g < mois.length; g++) {
        final f = find.text('entete-$g');
        if (f.evaluate().isEmpty) continue;
        expect(f.evaluate().length, 1,
            reason: 'a $offset px, entete-$g existe en double');
        vus[g] = tester.getTopLeft(f).dy;
      }

      // Un rang plus grand doit toujours se trouver plus bas.
      final rangs = vus.keys.toList()..sort();
      for (var i = 1; i < rangs.length; i++) {
        expect(
          vus[rangs[i]]!,
          greaterThan(vus[rangs[i - 1]]!),
          reason: 'a $offset px, entete-${rangs[i]} (${vus[rangs[i]]}) '
              'devrait etre sous entete-${rangs[i - 1]} '
              '(${vus[rangs[i - 1]]})',
        );
      }
    }
  }

  testWidgets('slivers poses directement : l\'ordre tient', (tester) async {
    // C'est la disposition retenue : une liste de slivers consecutifs, le
    // chemin le plus eprouve de Flutter.
    await verifierOrdre(tester, groupe: false);
  });

  testWidgets('les cartes ne remontent pas au-dessus de leur intertitre',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(page(mois, groupe: false));
    await tester.pumpAndSettle();

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;

    for (var offset = 0.0; offset < 4000; offset += 220) {
      position.jumpTo(offset);
      await tester.pump();

      for (var g = 0; g < mois.length; g++) {
        final entete = find.text('entete-$g');
        final carte = find.text('carte-$g-0');
        if (entete.evaluate().isEmpty || carte.evaluate().isEmpty) continue;

        expect(
          tester.getTopLeft(carte).dy,
          greaterThan(tester.getTopLeft(entete).dy),
          reason: 'a $offset px, carte-$g-0 passe au-dessus de son intertitre',
        );
      }
    }
  });
}
