/// Libellés de dates en français, sans dépendance à `intl`.
///
/// Les noms de mois étaient recopiés dans cinq écrans, avec des casses
/// différentes d'un fichier à l'autre. Les nouveaux affichages passent par
/// ici ; les anciens pourront y venir au fil des retouches.
library;

const List<String> moisFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Nom du mois, première lettre en capitale : « Octobre ».
String nomDuMois(int mois) {
  final nom = moisFr[(mois - 1).clamp(0, 11)];
  return nom[0].toUpperCase() + nom.substring(1);
}

/// Clé de regroupement mensuel, ordonnable : 2026 * 12 + 9 pour octobre 2026.
int cleDuMois(DateTime date) => date.year * 12 + date.month;

/// Intertitre d'un groupe de chroniques.
///
/// Les deux mois les plus récents sont nommés par leur distance plutôt que
/// par leur date : en haut d'une liste, « Ce mois-ci » se lit plus vite que
/// « Octobre 2026 », et c'est là que l'œil arrive en premier. Au-delà, la
/// date absolue redevient le repère utile.
String libelleDuMois(DateTime date, {DateTime? aujourdhui}) {
  final maintenant = aujourdhui ?? DateTime.now();
  final ecart = cleDuMois(maintenant) - cleDuMois(date);

  if (ecart == 0) return 'Ce mois-ci';
  if (ecart == 1) return 'Le mois dernier';

  // L'année ne s'affiche que si elle diffère : « Mars » dans l'année en
  // cours, « Mars 2025 » au-delà.
  if (date.year == maintenant.year) return nomDuMois(date.month);
  return '${nomDuMois(date.month)} ${date.year}';
}

/// Découpe une liste **déjà triée** en tranches mensuelles consécutives.
///
/// La fonction ne retrie rien : elle coupe là où le mois change. L'ordre
/// d'entrée est donc conservé à l'intérieur de chaque tranche, et deux
/// tranches ne peuvent pas porter le même mois — sauf si l'entrée n'était
/// pas triée, auquel cas le découpage reflète fidèlement ce désordre plutôt
/// que de le masquer.
List<List<T>> groupeParMois<T>(List<T> items, DateTime Function(T) dateDe) {
  final groupes = <List<T>>[];
  int? courant;

  for (final item in items) {
    final cle = cleDuMois(dateDe(item));
    if (cle != courant) {
      groupes.add(<T>[]);
      courant = cle;
    }
    groupes.last.add(item);
  }

  return groupes;
}
