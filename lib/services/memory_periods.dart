import '../models/note.dart';

/// Une distance dans le temps : « il y a trois mois ».
///
/// Les periodes etaient declarees dans le service de notifications, et la
/// selection s'arretait a la premiere qui trouvait une note. Comme la liste
/// commence par deux semaines et qu'un journal tenu regulierement a presque
/// toujours une note de quinze jours, les periodes lointaines n'etaient
/// jamais atteintes. Elles vivent maintenant ici, et le choix se fait sur
/// l'ensemble.
class MemoryPeriod {
  /// Age vise, en jours.
  final int days;

  /// Formule de la notification : « Il y a trois mois... ».
  final String label;

  /// Titre du diaporama : « Il y a trois mois ».
  final String title;

  const MemoryPeriod(this.days, this.label, this.title);

  static const List<MemoryPeriod> all = [
    MemoryPeriod(7, 'Il y a une semaine...', 'Il y a une semaine'),
    MemoryPeriod(14, 'Il y a deux semaines...', 'Il y a deux semaines'),
    MemoryPeriod(30, 'Il y a un mois...', 'Il y a un mois'),
    MemoryPeriod(90, 'Il y a trois mois...', 'Il y a trois mois'),
    MemoryPeriod(180, 'Il y a six mois...', 'Il y a six mois'),
    MemoryPeriod(365, 'Il y a un an...', 'Il y a un an'),
    MemoryPeriod(730, 'Il y a deux ans...', 'Il y a deux ans'),
    MemoryPeriod(1095, 'Il y a trois ans...', 'Il y a trois ans'),
  ];

  static MemoryPeriod? byDays(int days) {
    for (final period in all) {
      if (period.days == days) return period;
    }
    return null;
  }

  /// Marge acceptee autour de l'age vise.
  ///
  /// Elle s'elargit avec la distance : a un an pres, trois jours d'ecart ne
  /// veulent rien dire, et une marge trop etroite ne trouvait jamais rien.
  int get tolerance {
    if (days <= 14) return 1;
    if (days <= 30) return 2;
    if (days <= 180) return 4;
    return 7;
  }

  /// Les chroniques qui ont cet age, a la marge pres.
  List<Note> matching(List<Note> notes, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    return notes.where((note) {
      final age = reference.difference(note.createdAt).inDays;
      return age >= days - tolerance && age <= days + tolerance;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Les periodes qui ont effectivement quelque chose a montrer.
  static List<MemoryPeriod> available(List<Note> notes, {DateTime? now}) {
    return all
        .where((period) => period.matching(notes, now: now).isNotEmpty)
        .toList();
  }
}
