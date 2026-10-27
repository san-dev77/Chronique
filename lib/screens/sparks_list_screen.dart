import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/note.dart';
import '../models/spark.dart';
import '../services/note_service.dart';
import '../services/spark_service.dart';
import '../services/guidance_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';
import 'note_edit_screen.dart';
import 'spark_edit_screen.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive.dart';
import '../widgets/save_flash.dart';
import '../widgets/screen_header.dart';

class SparksListScreen extends StatefulWidget {
  const SparksListScreen({super.key});

  @override
  State<SparksListScreen> createState() => _SparksListScreenState();
}

class _SparksListScreenState extends State<SparksListScreen> {
  List<Spark> _sparks = [];
  bool _isLoading = true;
  String _pagePrompt = '';

  @override
  void initState() {
    super.initState();
    _pagePrompt = GuidanceService.instance.getRandomSparkPrompt();
    _loadSparks();
  }

  Future<void> _loadSparks() async {
    setState(() => _isLoading = true);
    final sparks = SparkService.instance.getAllSparks()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _sparks = sparks;
      _isLoading = false;
    });
  }

  Future<void> _saveSpark(Spark spark) async {
    await SparkService.instance.saveSpark(spark);
    _loadSparks();
  }

  void _editSpark(Spark spark) {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(
        SparkEditScreen(spark: spark, onSave: _saveSpark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AppTheme.skyBlue;

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final wide = Responsive.useSidebar(width);
      final insets = Responsive.contentInsets(width);
      final gutter = Responsive.gutter(width);

      return Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              screenHeaderSliver(
                width: width,
                pinnedHeight: 116,
                header: ScreenHeader(
                  width: width,
                  // Presente comme onglet dans la barre laterale, mais aussi
                  // empilee depuis Chroniques : la fleche n'apparait que dans
                  // le second cas.
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.pop(context)
                      : null,
                  icon: Icons.bolt_rounded,
                  title: 'Étincelles',
                  accent: _sparkAccent,
                  subtitle: _sparks.isEmpty
                      ? 'Vos idées à développer se rangeront ici'
                      : '${_sparks.length} idée${_sparks.length > 1 ? 's' : ''} en attente',
                  actions: [
                    _NewSparkButton(
                      accent: _sparkAccent,
                      compact: !wide,
                      onTap: _createSpark,
                    ),
                  ],
                ),
              ),

              // Invitation du moment
              if (_sparks.isNotEmpty && _pagePrompt.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        insets.left, wide ? 22 : 16, insets.right, 0),
                    child: _PromptBanner(
                      text: _pagePrompt,
                      accent: _sparkAccent,
                      isDark: isDark,
                    ),
                  ),
                ),

              if (_isLoading)
                const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()))
              else if (_sparks.isEmpty)
                SliverFillRemaining(child: _buildEmptyState(isDark))
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    insets.left,
                    18,
                    insets.right,
                    wide ? 40 : 100,
                  ),
                  sliver: SliverMasonryGrid.count(
                    crossAxisCount:
                        Responsive.noteColumns(width - insets.horizontal),
                    mainAxisSpacing: gutter,
                    crossAxisSpacing: gutter,
                    itemBuilder: (context, index) {
                      final spark = _sparks[index];
                      return _buildSparkCard(spark, isDark, accentColor);
                    },
                    childCount: _sparks.length,
                  ),
                ),
            ],
          ),
        ),
        // Sur desktop, la creation vit dans l'en-tete : un bouton flottant en
        // bas a droite n'est pas la ou l'oeil le cherche.
        floatingActionButton: wide
            ? null
            : FloatingActionButton(
                heroTag: 'fab_sparks',
                onPressed: _createSpark,
                backgroundColor: _sparkAccent,
                elevation: 4,
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 28),
              ),
      );
    });
  }

  /// L'accent de l'application, qui suit la couleur choisie par l'utilisateur.
  Color get _sparkAccent => AppTheme.skyBlue;

  void _createSpark() {
    Navigator.push(
      context,
      PageTransitions.scaleTransition(SparkEditScreen(onSave: _saveSpark)),
    );
  }

  Widget _buildSparkCard(Spark spark, bool isDark, Color accentColor) {
    return _SparkCard(
      key: ValueKey(spark.id),
      spark: spark,
      isDark: isDark,
      accent: accentColor,
      onTap: () => _editSpark(spark),
      onDevelop: () => _developSpark(spark),
      onOptions: () {
        HapticFeedback.mediumImpact();
        _showOptions(spark);
      },
    );
  }

  /// Transforme une etincelle en chronique.
  ///
  /// C'est la raison d'etre d'une etincelle : elle attend d'etre developpee.
  /// L'action n'existait que depuis l'ecran Chroniques, c'est-a-dire partout
  /// sauf la ou les etincelles vivent.
  void _developSpark(Spark spark) {
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: spark.title,
      content: spark.description ?? '',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      imagePaths: spark.imagePath != null ? [spark.imagePath!] : const [],
    );

    Navigator.push(
      context,
      PageTransitions.scaleTransition(
        NoteEditScreen(
          note: note,
          onSave: (saved) async {
            await NoteService.instance.saveNote(saved, isNew: true);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Étincelle développée en chronique'),
              ));
            }
          },
        ),
      ),
    );
  }

  /// Les actions d'une etincelle.
  ///
  /// L'ancienne feuille empilait deux `ListTile` avec des pastilles bleue et
  /// rouge codees en dur : elle n'avait rien de commun avec le reste de
  /// l'application. Et sur desktop, une feuille qui monte du bas pour un
  /// clic droit n'est pas ce que l'on attend.
  void _showOptions(Spark spark) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.surfaceDark : Colors.white;

    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SparkAction(
          icon: Icons.auto_stories_rounded,
          label: 'Développer en chronique',
          hint: 'Reprendre cette idée et l’écrire',
          color: _sparkAccent,
          onTap: () {
            Navigator.pop(context);
            _developSpark(spark);
          },
        ),
        _SparkAction(
          icon: Icons.edit_rounded,
          label: 'Modifier',
          hint: 'Retoucher le titre ou la note',
          color: _sparkAccent,
          onTap: () {
            Navigator.pop(context);
            _editSpark(spark);
          },
        ),
        _SparkAction(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          hint: 'Effacer définitivement cette étincelle',
          color: const Color(0xFFE05252),
          onTap: () async {
            Navigator.pop(context);
            await SparkService.instance.deleteSpark(spark.id);
            if (mounted) await showDeleteFlash(context);
            _loadSparks();
          },
        ),
      ],
    );

    final panel = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : _sparkAccent.withValues(alpha: 0.12),
        ),
      ),
      child: actions,
    );

    if (Responsive.isWide(context)) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: panel,
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            actions,
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final accent = _sparkAccent;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Halo doux plutot qu'un aplat : l'ecran vide reste vivant.
            Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    accent.withValues(alpha: isDark ? 0.28 : 0.16),
                    accent.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent,
                        Color.lerp(accent, Colors.black, 0.25)!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.36),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      size: 30, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Text(
              "Rien pour l'instant",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: isDark ? AppTheme.textLight : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              "Une étincelle, c'est une idée jetée vite fait — "
              'une phrase, une image. Vous en ferez une chronique plus tard.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.6,
                color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 26),
            _NewSparkButton(
              accent: accent,
              compact: false,
              onTap: _createSpark,
            ),
          ],
        ),
      ),
    );
  }

}

/// Bouton de creation d'etincelle, loge dans l'en-tete sur desktop.
class _NewSparkButton extends StatefulWidget {
  final Color accent;
  final bool compact;
  final VoidCallback onTap;

  const _NewSparkButton({
    required this.accent,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_NewSparkButton> createState() => _NewSparkButtonState();
}

class _NewSparkButtonState extends State<_NewSparkButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return const SizedBox.shrink();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accent,
                Color.lerp(widget.accent, Colors.black, 0.2)!,
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: _hover ? 0.46 : 0.26),
                blurRadius: _hover ? 18 : 10,
                offset: Offset(0, _hover ? 6 : 3),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 18),
              SizedBox(width: 7),
              Text(
                'Nouvelle étincelle',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Invitation a ecrire, affichee au-dessus de la grille.
class _PromptBanner extends StatelessWidget {
  final String text;
  final Color accent;
  final bool isDark;

  const _PromptBanner({
    required this.text,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: accent, size: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
                color: isDark ? Colors.white70 : AppTheme.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte d'etincelle.
///
/// Une etincelle est une idee brute, pas une chronique : la carte doit se lire
/// d'un coup d'oeil et donner envie de la developper. D'ou le format court,
/// la pastille eclair qui la signe, et l'invitation qui apparait au survol.
class _SparkCard extends StatefulWidget {
  final Spark spark;
  final bool isDark;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onDevelop;
  final VoidCallback onOptions;

  const _SparkCard({
    super.key,
    required this.spark,
    required this.isDark,
    required this.accent,
    required this.onTap,
    required this.onDevelop,
    required this.onOptions,
  });

  /// Teinte propre a chaque etincelle, tiree de son identifiant.
  ///
  /// Un mur d'idees jetees a la volee ne devrait pas etre un mur de cartes
  /// blanches identiques. La teinte est stable — la meme idee garde sa
  /// couleur d'un lancement a l'autre — et reste dans la famille de
  /// l'accent, pour ne pas transformer l'ecran en nuancier.
  Color get tint {
    var h = 0;
    for (final unit in spark.id.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    const palette = [
      Color(0xFF4A90D9), Color(0xFF6C8FE0), Color(0xFF4FA8C8),
      Color(0xFF8B6FD6), Color(0xFF3FA68C), Color(0xFFE09B3D),
      Color(0xFFD67B9B), Color(0xFF5B9BD5),
    ];
    return palette[h % palette.length];
  }

  @override
  State<_SparkCard> createState() => _SparkCardState();
}

class _SparkCardState extends State<_SparkCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final spark = widget.spark;
    final isDark = widget.isDark;
    final accent = widget.tint;
    final surface = isDark ? AppTheme.cardDark : Colors.white;
    final hasImage = spark.imagePath != null;
    final hasDescription =
        spark.description != null && spark.description!.trim().isNotEmpty;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onOptions,
          onSecondaryTap: widget.onOptions,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            transform: Matrix4.identity()..translate(0.0, _hover ? -4.0 : 0.0),
            // clipBehavior sur le conteneur : les enfants sont rognes
            // exactement a la forme de la decoration, a l'interieur de la
            // bordure. Un ClipRRect interieur d'un rayon different laissait
            // passer un liseré d'un pixel, tres visible au survol.
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              // Une teinte tres diluee en haut a gauche, qui rejoint la
              // surface avant d'atteindre l'image : le fondu de la photo
              // tombe ainsi sur une couleur unie, sans second raccord.
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: const [0, 0.42, 1],
                colors: [
                  Color.lerp(surface, accent, isDark ? 0.17 : 0.085)!,
                  surface,
                  surface,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: accent.withValues(alpha: _hover ? 0.42 : 0.13),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hover
                      ? accent.withValues(alpha: 0.26)
                      : Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
                  blurRadius: _hover ? 26 : 14,
                  offset: Offset(0, _hover ? 12 : 5),
                ),
              ],
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasImage) _buildImage(spark, accent, surface),
                  Padding(
                    padding: EdgeInsets.fromLTRB(15, hasImage ? 13 : 16, 15, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!hasImage) ...[
                          _boltBadge(accent),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          spark.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            height: 1.32,
                            letterSpacing: -0.2,
                            color: isDark
                                ? AppTheme.textLight
                                : AppTheme.textDark,
                          ),
                        ),
                        if (hasDescription) ...[
                          const SizedBox(height: 7),
                          Text(
                            spark.description!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.55,
                              color: (isDark
                                      ? AppTheme.textMutedDark
                                      : AppTheme.textMuted)
                                  .withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        _footer(spark, accent, isDark),
                      ],
                    ),
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }

  /// Pastille eclair : la signature visuelle d'une etincelle.
  Widget _boltBadge(Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: widget.isDark ? 0.20 : 0.11),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            'IDÉE',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(Spark spark, Color accent, Color surface) {
    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final dpr = MediaQuery.devicePixelRatioOf(context);
              return AnimatedScale(
                duration: AppMotion.slow,
                curve: AppMotion.enter,
                scale: _hover ? 1.06 : 1,
                child: Image.file(
                  File(spark.imagePath!),
                  fit: BoxFit.cover,
                  cacheWidth: c.maxWidth.isFinite && c.maxWidth > 0
                      ? (c.maxWidth * dpr).round()
                      : null,
                  errorBuilder: (_, __, ___) =>
                      Container(color: Colors.black26),
                ),
              );
            },
          ),
          // Fondu vers la carte : l'image ne se termine pas par une arete.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 52,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface.withValues(alpha: 0), surface],
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: 10, left: 10, child: _boltBadge(accent)),
        ],
      ),
    );
  }

  Widget _footer(Spark spark, Color accent, bool isDark) {
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMuted;
    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 12, color: muted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            DateFormatter.formatRelativeDate(spark.createdAt),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
        ),
        // L'action qui compte vraiment, revelee au survol : une etincelle
        // n'attend que d'etre developpee. Au repos, la carte reste une idee.
        AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: _hover ? 1 : 0,
          child: _DevelopButton(
            accent: accent,
            enabled: _hover,
            onTap: widget.onDevelop,
          ),
        ),
      ],
    );
  }
}


/// Bouton « Développer », revele au survol d'une carte d'etincelle.
class _DevelopButton extends StatefulWidget {
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  const _DevelopButton({
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_DevelopButton> createState() => _DevelopButtonState();
}

class _DevelopButtonState extends State<_DevelopButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Tooltip(
      message: 'Développer en chronique',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          // Desactive tant que la carte n'est pas survolee : sinon un bouton
          // invisible resterait cliquable.
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: _hover ? 0.20 : 0.11),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: accent.withValues(alpha: _hover ? 0.45 : 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_stories_rounded, size: 12, color: accent),
                const SizedBox(width: 5),
                Text(
                  'Développer',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Une action du menu d'une etincelle.
class _SparkAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final String hint;
  final Color color;
  final VoidCallback onTap;

  const _SparkAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SparkAction> createState() => _SparkActionState();
}

class _SparkActionState extends State<_SparkAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _hover
                ? color.withValues(alpha: isDark ? 0.15 : 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, size: 19, color: color),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.hint,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                duration: AppMotion.fast,
                offset: Offset(_hover ? 0.2 : 0, 0),
                child: Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: _hover
                        ? color
                        : (isDark ? Colors.white30 : Colors.black26)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
