import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le défilement revenait en arrière « encore et encore ».
///
/// Les tests précédents utilisaient `jumpTo`, qui court-circuite la physique
/// et les corrections d'étendue : ils ne pouvaient pas voir le défaut. Ici
/// on fait glisser pour de vrai, et on surveille `maxScrollExtent`.
///
/// Une grille en maçonnerie ne connaît pas sa hauteur avant d'avoir construit
/// ses cartes : elle l'estime. Quinze grilles successives, c'est quinze
/// estimations qui se corrigent au fil du défilement — et une estimation qui
/// rétrécit rappelle la position vers le haut.
void main() {
  const mois = [11, 8, 13, 5, 4, 7, 11, 13, 17, 11, 10, 10, 10, 13, 5];

  /// Hauteurs irrégulières, comme de vraies chroniques : certaines portent
  /// une photo, d'autres trois lignes de texte.
  double hauteur(int g, int i) => 90.0 + ((g * 7 + i * 13) % 5) * 55;

  /// Les dispositions en lice.
  Widget page({required String variante}) {
    final slivers = <Widget>[];

    if (variante == 'mois-suite' || variante == 'mois-groupe') {
      for (var g = 0; g < mois.length; g++) {
        slivers.add(SliverToBoxAdapter(
          child: SizedBox(height: 44, child: Text('entete-$g')),
        ));
        slivers.add(SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childCount: mois[g],
          itemBuilder: (_, i) => SizedBox(height: hauteur(g, i)),
        ));
      }
    } else if (variante == 'section-eager') {
      // Une section par mois, chacune dans un SliverToBoxAdapter qui porte
      // une MasonryGridView non defilante. L'etendue de la section est donc
      // connue des sa construction — aucune estimation a corriger.
      //
      // La paresse demeure au niveau de la SECTION : un mois hors champ
      // n'est pas construit du tout. Un mois compte au plus dix-sept
      // chroniques, donc la poussee memoire reste bornee.
      for (var g = 0; g < mois.length; g++) {
        slivers.add(SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 44, child: Text('entete-$g')),
              MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: mois[g],
                itemBuilder: (_, i) => SizedBox(height: hauteur(g, i)),
              ),
            ],
          ),
        ));
      }
    } else if (variante == 'section-sliverlist') {
      slivers.add(SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, g) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 44, child: Text('entete-$g')),
              MasonryGridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                itemCount: mois[g],
                itemBuilder: (_, i) => SizedBox(height: hauteur(g, i)),
              ),
            ],
          ),
          childCount: mois.length,
        ),
      ));
    } else if (variante == 'mois-grille-fixe') {
      // Hauteur de carte uniforme : l'etendue se calcule par arithmetique,
      // sans construire une seule carte. Aucune estimation, donc aucune
      // correction — au prix de la maconnerie.
      for (var g = 0; g < mois.length; g++) {
        slivers.add(SliverToBoxAdapter(
          child: SizedBox(height: 44, child: Text('entete-$g')),
        ));
        slivers.add(SliverGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.78,
          children: [
            for (var i = 0; i < mois[g]; i++) const SizedBox.shrink(),
          ],
        ));
      }
    } else if (variante == 'retenue') {
      // Grille unique, legende de mois posee sur la premiere carte de
      // chaque mois : quinze cartes sont plus hautes de 24 px.
      final debuts = <int>{};
      var rang = 0;
      for (final n in mois) {
        debuts.add(rang);
        rang += n;
      }
      final total = mois.fold<int>(0, (a, b) => a + b);
      slivers.add(SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: total,
        itemBuilder: (_, i) => SizedBox(
          height: hauteur(i ~/ 10, i % 10) + (debuts.contains(i) ? 24 : 0),
        ),
      ));
    } else {
      // La disposition d'avant : une seule grille pour tout.
      final total = mois.fold<int>(0, (a, b) => a + b);
      slivers.add(SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childCount: total,
        itemBuilder: (_, i) => SizedBox(height: hauteur(i ~/ 10, i % 10)),
      ));
    }

    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: variante == 'mois-groupe'
              ? [SliverMainAxisGroup(slivers: slivers)]
              : slivers,
        ),
      ),
    );
  }

  /// Fait descendre la liste par glissements successifs et rapporte le plus
  /// grand recul observé, ainsi que les rétrécissements d'étendue.
  Future<({double recul, int retrecissements})> descendre(
    WidgetTester tester, {
    required String variante,
  }) async {
    tester.view.physicalSize = const Size(720, 1560);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(page(variante: variante));
    await tester.pumpAndSettle();

    // `.first` : la variante a sections imbrique des MasonryGridView,
    // qui sont eux-memes des Scrollable. Celui du CustomScrollView
    // exterieur vient en premier dans l'arbre.
    final position =
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    var recul = 0.0;
    var retrecissements = 0;
    var precedent = position.pixels;
    var etendue = position.maxScrollExtent;

    for (var pas = 0; pas < 30; pas++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -260));
      await tester.pumpAndSettle();

      final maintenant = position.pixels;
      if (maintenant < precedent) {
        final r = precedent - maintenant;
        if (r > recul) recul = r;
      }
      precedent = maintenant;

      if (position.maxScrollExtent < etendue - 1) retrecissements++;
      etendue = position.maxScrollExtent;

      if (maintenant >= position.maxScrollExtent - 1) break;
    }

    return (recul: recul, retrecissements: retrecissements);
  }

  for (final v in ['grille-unique', 'mois-suite', 'mois-groupe',
    'mois-grille-fixe', 'retenue', 'section-eager', 'section-sliverlist']) {
    testWidgets('recul : $v', (tester) async {
      final r = await descendre(tester, variante: v);
      print('%%% $v — recul ${r.recul} px, '
          'retrecissements ${r.retrecissements}');

      if (v == 'section-sliverlist' || v == 'grille-unique') {
        expect(r.recul, lessThan(1),
            reason: 'la disposition « $v » doit tenir le defilement ; '
                'recul observe ${r.recul} px');
      }
    });
  }
}
