import 'package:flutter/material.dart';

import '../models/note.dart';
import '../theme/app_theme.dart';
import '../utils/french_dates.dart';
import '../utils/responsive.dart';
import 'motion.dart';

/// Feuille de recherche des chroniques.
///
/// L'ancienne version empilait quatre choses sans hiérarchie — un titre
/// « Recherche & Filtres », un champ, des filtres, des actions rapides, un
/// bouton « Appliquer » — et surtout : **elle n'affichait aucun résultat**.
/// On tapait dans le vide, puis on fermait pour découvrir ce qui avait été
/// trouvé. D'où l'impression de désordre : la feuille posait une question
/// sans jamais y répondre.
///
/// Ici elle n'a qu'un rôle à la fois. Champ vide, c'est un point de départ :
/// filtres et raccourcis. Dès qu'on écrit, elle devient une liste de
/// réponses, le terme cherché surligné à l'endroit où il apparaît.
class SearchSheet extends StatelessWidget {
  final TextEditingController controller;
  final String query;

  final List<String> filters;
  final List<int> filterCounts;
  final int selectedFilter;
  final ValueChanged<int> onFilterChanged;

  /// Chroniques déjà filtrées par l'écran appelant.
  final List<Note> results;
  final ValueChanged<Note> onOpenNote;

  final int sparkCount;
  final int quoteCount;
  final int favoriteCount;
  final VoidCallback onOpenSparks;
  final VoidCallback onOpenQuotes;
  final VoidCallback onShowFavorites;

  const SearchSheet({
    super.key,
    required this.controller,
    required this.query,
    required this.filters,
    required this.filterCounts,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.results,
    required this.onOpenNote,
    required this.sparkCount,
    required this.quoteCount,
    required this.favoriteCount,
    required this.onOpenSparks,
    required this.onOpenQuotes,
    required this.onShowFavorites,
  });

  bool get _searching => query.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = AppTheme.skyBlue;

    return Padding(
      // Le clavier pousse la feuille au lieu de recouvrir le champ.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          children: [
            _Handle(isDark: isDark),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _Field(
                controller: controller,
                query: query,
                accent: accent,
                isDark: isDark,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
              child: _FilterRow(
                filters: filters,
                counts: filterCounts,
                selected: selectedFilter,
                onSelect: onFilterChanged,
                accent: accent,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: _searching
                    ? _Results(
                        key: const ValueKey('resultats'),
                        results: results,
                        query: query.trim(),
                        onOpenNote: onOpenNote,
                        accent: accent,
                        isDark: isDark,
                      )
                    : _Start(
                        key: const ValueKey('depart'),
                        isDark: isDark,
                        sparkCount: sparkCount,
                        quoteCount: quoteCount,
                        favoriteCount: favoriteCount,
                        onOpenSparks: onOpenSparks,
                        onOpenQuotes: onOpenQuotes,
                        onShowFavorites: onShowFavorites,
                        total: results.length,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  final bool isDark;
  const _Handle({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 4,
      margin: const EdgeInsets.only(top: 10, bottom: 14),
      decoration: BoxDecoration(
        // L'ancienne poignee etait en grey.shade300 : invisible en clair,
        // criarde en sombre. Elle suit desormais le theme.
        color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Champ de saisie.
///
/// Une seule icône de loupe, dans le champ. L'ancienne version en avait deux
/// — une dans l'en-tête, une en préfixe — ce qui donnait à la feuille un air
/// de formulaire bavard.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final Color accent;
  final bool isDark;

  const _Field({
    required this.controller,
    required this.query,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final rempli = query.isNotEmpty;

    return AnimatedContainer(
      duration: AppMotion.fast,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          // Le cadre se teinte quand on écrit : le champ dit qu'il travaille.
          color: rempli
              ? accent.withValues(alpha: isDark ? 0.45 : 0.32)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
          width: 1.2,
        ),
      ),
      child: TextField(
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textDark,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'Chercher dans mes chroniques',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : AppTheme.textMuted,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 21,
            color: rempli
                ? accent
                : (isDark ? Colors.white38 : AppTheme.textMuted),
          ),
          suffixIcon: rempli
              ? IconButton(
                  tooltip: 'Effacer',
                  icon: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: isDark ? Colors.white54 : AppTheme.textMuted,
                  ),
                  onPressed: controller.clear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

/// Rangée de filtres, défilante.
///
/// Les pastilles étaient des blocs d'accent pleins, posés dans un Wrap qui
/// se réorganisait à chaque frappe — c'est ce remuement qui donnait le plus
/// fort sentiment de désordre. Une seule ligne qui défile ne bouge plus, et
/// seul le filtre actif porte la couleur.
class _FilterRow extends StatelessWidget {
  final List<String> filters;
  final List<int> counts;
  final int selected;
  final ValueChanged<int> onSelect;
  final Color accent;
  final bool isDark;

  const _FilterRow({
    required this.filters,
    required this.counts,
    required this.selected,
    required this.onSelect,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _Chip(
          label: filters[i],
          count: i < counts.length ? counts[i] : 0,
          selected: selected == i,
          accent: accent,
          isDark: isDark,
          onTap: () => onSelect(i),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? accent
        : (isDark ? AppTheme.textMutedDark : AppTheme.textMuted);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: isDark ? 0.16 : 0.10)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.045)
                  : Colors.black.withValues(alpha: 0.032)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.5 : 0.34)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.045)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: fg,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: fg.withValues(alpha: 0.72),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Écran de départ, quand rien n'est encore cherché.
class _Start extends StatelessWidget {
  final bool isDark;
  final int sparkCount;
  final int quoteCount;
  final int favoriteCount;
  final int total;
  final VoidCallback onOpenSparks;
  final VoidCallback onOpenQuotes;
  final VoidCallback onShowFavorites;

  const _Start({
    super.key,
    required this.isDark,
    required this.sparkCount,
    required this.quoteCount,
    required this.favoriteCount,
    required this.total,
    required this.onOpenSparks,
    required this.onOpenQuotes,
    required this.onShowFavorites,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      children: [
        _SectionLabel('Aller à', isDark: isDark),
        const SizedBox(height: 12),
        _Shortcut(
          icon: Icons.bolt_rounded,
          label: 'Étincelles',
          hint: 'Les idées pas encore écrites',
          count: sparkCount,
          tint: Colors.orange.shade400,
          isDark: isDark,
          onTap: onOpenSparks,
        ),
        const SizedBox(height: 10),
        _Shortcut(
          icon: Icons.format_quote_rounded,
          label: 'Citations',
          hint: 'Les phrases gardées',
          count: quoteCount,
          tint: const Color(0xFF8B6FD6),
          isDark: isDark,
          onTap: onOpenQuotes,
        ),
        const SizedBox(height: 10),
        _Shortcut(
          icon: Icons.favorite_rounded,
          label: 'Favoris',
          hint: 'Celles qui comptent',
          count: favoriteCount,
          tint: Colors.red.shade400,
          isDark: isDark,
          onTap: onShowFavorites,
        ),
        const SizedBox(height: 26),
        Center(
          child: Text(
            total == 0
                ? 'Aucune chronique pour ce filtre'
                : '$total chronique${total > 1 ? 's' : ''} dans ce filtre',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: (isDark ? AppTheme.textMutedDark : AppTheme.textMuted)
            .withValues(alpha: 0.9),
      ),
    );
  }
}

class _Shortcut extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final int count;
  final Color tint;
  final bool isDark;
  final VoidCallback onTap;

  const _Shortcut({
    required this.icon,
    required this.label,
    required this.hint,
    required this.count,
    required this.tint,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.black.withValues(alpha: 0.022),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: isDark ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: tint),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color:
                          isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: tint,
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}

/// Liste des réponses.
class _Results extends StatelessWidget {
  final List<Note> results;
  final String query;
  final ValueChanged<Note> onOpenNote;
  final Color accent;
  final bool isDark;

  const _Results({
    super.key,
    required this.results,
    required this.query,
    required this.onOpenNote,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return _Empty(query: query, isDark: isDark);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
      itemCount: results.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _SectionLabel(
              '${results.length} trouvée${results.length > 1 ? 's' : ''}',
              isDark: isDark,
            ),
          );
        }
        return _ResultRow(
          note: results[i - 1],
          query: query,
          accent: accent,
          isDark: isDark,
          onTap: () => onOpenNote(results[i - 1]),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final String query;
  final bool isDark;
  const _Empty({required this.query, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 34,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 14),
            Text(
              'Rien pour « $query »',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'La recherche regarde les titres, le contenu et les citations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une réponse : son titre, la date, et l'extrait où le terme apparaît.
class _ResultRow extends StatelessWidget {
  final Note note;
  final String query;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _ResultRow({
    required this.note,
    required this.query,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final titre = note.title.trim().isEmpty ? 'Sans titre' : note.title.trim();
    final extrait = extraitAutourDe(note, query);

    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.035)
              : Colors.black.withValues(alpha: 0.022),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.055)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Surligne(
                    texte: titre,
                    terme: query,
                    accent: accent,
                    base: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: isDark ? Colors.white : AppTheme.textDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (note.imagePaths.isNotEmpty)
                  Icon(
                    Icons.image_outlined,
                    size: 15,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                if (note.isFavorite) ...[
                  const SizedBox(width: 5),
                  Icon(Icons.favorite_rounded,
                      size: 14, color: Colors.red.shade300),
                ],
              ],
            ),
            if (extrait.isNotEmpty) ...[
              const SizedBox(height: 5),
              _Surligne(
                texte: extrait,
                terme: query,
                accent: accent,
                maxLines: 2,
                base: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              '${note.createdAt.day} ${moisFr[note.createdAt.month - 1]} '
              '${note.createdAt.year}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: (isDark ? AppTheme.textMutedDark : AppTheme.textMuted)
                    .withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texte dont chaque occurrence de [terme] est mise en évidence.
///
/// C'est ce qui fait la différence entre une liste de titres et une
/// recherche : on voit *pourquoi* une chronique répond.
class _Surligne extends StatelessWidget {
  final String texte;
  final String terme;
  final Color accent;
  final TextStyle base;
  final int? maxLines;

  const _Surligne({
    required this.texte,
    required this.terme,
    required this.accent,
    required this.base,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final morceaux = decoupeSurTerme(texte, terme);

    return Text.rich(
      TextSpan(
        children: [
          for (final m in morceaux)
            TextSpan(
              text: m.texte,
              style: m.correspond
                  ? base.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    )
                  : base,
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

/// Un fragment de texte, correspondant au terme cherché ou non.
class Fragment {
  final String texte;
  final bool correspond;

  const Fragment(this.texte, this.correspond);

  @override
  String toString() => correspond ? '[$texte]' : texte;
}

/// Découpe [texte] en fragments, en isolant chaque occurrence de [terme].
///
/// La comparaison ignore la casse mais les fragments gardent le texte
/// d'origine : on surligne « Marie » et non « marie ».
List<Fragment> decoupeSurTerme(String texte, String terme) {
  if (terme.isEmpty) return [Fragment(texte, false)];

  final cible = texte.toLowerCase();
  final cherche = terme.toLowerCase();
  final out = <Fragment>[];

  var debut = 0;
  while (true) {
    final trouve = cible.indexOf(cherche, debut);
    if (trouve < 0) break;

    if (trouve > debut) {
      out.add(Fragment(texte.substring(debut, trouve), false));
    }
    out.add(Fragment(texte.substring(trouve, trouve + terme.length), true));
    debut = trouve + terme.length;
  }

  if (debut < texte.length) {
    out.add(Fragment(texte.substring(debut), false));
  }

  return out.isEmpty ? [Fragment(texte, false)] : out;
}

/// Extrait du contenu centré sur la première occurrence de [terme].
///
/// Montrer les premiers mots d'une chronique n'aide pas quand le terme
/// cherché apparaît trois paragraphes plus loin. On cadre donc autour de la
/// trouvaille, en reculant un peu pour garder le début de la phrase.
String extraitAutourDe(Note note, String terme, {int longueur = 120}) {
  final sources = <String>[
    note.content.trim(),
    (note.quote ?? '').trim(),
  ].where((s) => s.isNotEmpty);

  final cherche = terme.toLowerCase();

  for (final source in sources) {
    final plat = source.replaceAll(RegExp(r'\s+'), ' ');
    final position = plat.toLowerCase().indexOf(cherche);
    if (position < 0) continue;

    // Trente caracteres de contexte avant le terme : assez pour situer la
    // phrase, pas assez pour repousser la trouvaille hors de l'ecran.
    var debut = position - 30;
    if (debut < 0) debut = 0;
    var fin = debut + longueur;
    if (fin > plat.length) fin = plat.length;

    final coupe = plat.substring(debut, fin).trim();
    return '${debut > 0 ? '… ' : ''}$coupe${fin < plat.length ? ' …' : ''}';
  }

  // Le terme n'est que dans le titre : on montre le debut du contenu.
  final premier = sources.isEmpty ? '' : sources.first;
  if (premier.isEmpty) return '';
  final plat = premier.replaceAll(RegExp(r'\s+'), ' ');
  return plat.length <= longueur
      ? plat
      : '${plat.substring(0, longueur).trim()} …';
}

/// Relie le champ de saisie à la feuille.
///
/// `showModalBottomSheet` pose la feuille dans une route à part : elle n'est
/// pas dans l'arbre de l'écran qui l'a ouverte, et un `setState` de cet
/// écran ne la redessine donc pas. Sans cet intermédiaire, on tapait dans le
/// champ et la liste restait figée — le défaut qui rendait la recherche
/// muette.
class SearchSheetHost extends StatefulWidget {
  final TextEditingController controller;

  /// Appelé à chaque frappe, pour que l'écran refasse son filtrage.
  final VoidCallback onQueryChanged;

  final Widget Function(String query) builder;

  const SearchSheetHost({
    super.key,
    required this.controller,
    required this.onQueryChanged,
    required this.builder,
  });

  @override
  State<SearchSheetHost> createState() => _SearchSheetHostState();
}

class _SearchSheetHostState extends State<SearchSheetHost> {
  late String _query = widget.controller.text;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    final texte = widget.controller.text;
    if (texte == _query) return;
    _query = texte;
    widget.onQueryChanged();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(_query);
}
