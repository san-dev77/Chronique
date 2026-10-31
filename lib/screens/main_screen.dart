import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'notes_screen.dart' show NotesScreen, NotesScreenActions;
import 'favorites_screen.dart';
import 'memories_screen.dart';
import 'settings_screen.dart';
import 'shared_notes_screen.dart';
import 'spark_edit_screen.dart';
import 'sparks_list_screen.dart';
import 'quote_edit_screen.dart';
import 'quotes_screen.dart';
import 'timeline_screen.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/accent_color_service.dart';
import '../services/guidance_service.dart';
import '../theme/app_theme.dart';
import '../utils/tactile.dart';
import '../services/sharing_service.dart';
import 'dart:async';
import 'dart:math';
import '../models/note.dart';
import '../models/spark.dart';
import '../services/note_service.dart';
import '../services/spark_service.dart';
import 'note_compose_flow.dart';
import '../utils/page_transitions.dart';
import '../utils/responsive.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/create_chooser.dart';
import '../widgets/user_avatar.dart';

class MainScreen extends StatefulWidget {
  final int initialTab;
  static _MainScreenState? of(BuildContext context) => 
      context.findAncestorStateOfType<_MainScreenState>();

  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

enum SyncStatus { idle, syncing, success, offline, error }

/// Raccourcis clavier attendus sur un poste de travail.
class NewNoteIntent extends Intent {
  const NewNoteIntent();
}

class SelectTabIntent extends Intent {
  final int index;
  const SelectTabIntent(this.index);
}

class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

/// Point d'entree pour changer d'onglet depuis un ecran enfant.
///
/// L'avatar de l'ecran Chroniques faisait `pushNamed('/main')` : cela empilait
/// une seconde instance de l'application au lieu de changer d'onglet, et
/// l'index vise n'etait plus le bon depuis l'ajout des Etincelles.
class MainScreenActions {
  MainScreenActions._();

  /// Index de l'onglet Reglages dans `_screens`.
  static const int settingsTab = 7;

  /// Index de l'onglet Citations.
  static const int quotesTab = 2;

  static void Function(int index)? goToTab;
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex = 0;
  SyncStatus _syncStatus = SyncStatus.idle;
  SyncReport? _lastSyncReport;
  bool _isConnected = true;
  StreamSubscription? _connectivitySub;

  final _screens = const [
    NotesScreen(),
    SparksListScreen(),
    QuotesScreen(),
    SharedNotesScreen(),
    MemoriesScreen(),
    FavoritesScreen(),
    TimelineScreen(),
    SettingsScreen()
  ];

  /// Onglets deja ouverts au moins une fois.
  ///
  /// L'IndexedStack monte tous ses enfants d'un coup pour leur garder leur
  /// etat. Sur desktop c'est gratuit ; sur un telephone de trois gigaoctets,
  /// les huit ecrans chargeaient leurs images en meme temps — y compris
  /// l'album et les souvenirs, les deux plus gourmands — et Android tuait
  /// l'application. On ne construit donc un onglet qu'a sa premiere visite.
  /// Une fois visite, il reste monte : son etat et sa position de defilement
  /// sont preserves comme avant.
  final Set<int> _visited = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    _isConnected = ConnectivityService.instance.isConnected;
    _connectivitySub =
        ConnectivityService.instance.connectivityStream.listen((c) {
      setState(() => _isConnected = c);
      if (c && AuthService.instance.isSignedIn) _sync();
    });
    _sync();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    if (MainScreenActions.goToTab == _goToTab) {
      MainScreenActions.goToTab = null;
    }
    super.dispose();
  }

  Future<void> _sync() async {
    if (!AuthService.instance.isSignedIn || !_isConnected) {
      setState(() =>
          _syncStatus = _isConnected ? SyncStatus.idle : SyncStatus.offline);
      return;
    }
    setState(() => _syncStatus = SyncStatus.syncing);
    try {
      final report = await CloudSyncService.instance.syncAll();
      if (mounted) {
        setState(() {
          _lastSyncReport = report;
          _syncStatus = report.success ? SyncStatus.success : SyncStatus.error;
        });
        
        // Cacher automatiquement le badge "Success" après 5 secondes
        if (report.success) {
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _syncStatus == SyncStatus.success) {
              setState(() => _syncStatus = SyncStatus.idle);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _syncStatus = SyncStatus.error;
          _lastSyncReport = SyncReport()
            ..success = false
            ..errorMessage = e.toString();
        });
      }
    }
  }

  void _goToTab(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    MainScreenActions.goToTab = _goToTab;
  }

  /// Creation d'une chronique, depuis la barre laterale ou Ctrl+N.
  /// Le bouton « Nouvelle » demande d'abord de quoi il s'agit.
  Future<void> _createNote() async {
    final kind = await showCreateChooser(context);
    if (kind == null || !mounted) return;

    switch (kind) {
      case CreateKind.note:
        Navigator.push(
          context,
          PageTransitions.scaleTransition(
            NoteComposeFlow(
              onSave: (note) => NoteService.instance.saveNote(note),
            ),
          ),
        );
      case CreateKind.quote:
        Navigator.push(
          context,
          PageTransitions.scaleTransition(
            QuoteEditScreen(
              onSave: (note, {bool isNew = false}) =>
                  NoteService.instance.saveNote(note, isNew: isNew),
            ),
          ),
        );
      case CreateKind.spark:
        Navigator.push(
          context,
          PageTransitions.scaleTransition(
            SparkEditScreen(
              onSave: (spark) => SparkService.instance.saveSpark(spark),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSignedIn = AuthService.instance.isSignedIn;

    // Marque l'onglet affiche comme visite. Le faire ici plutot que dans
    // chaque setState evite qu'un futur chemin de navigation oublie de le
    // declarer et affiche un onglet vide. L'ensemble ne fait que croitre et
    // il est relu dans la meme passe : aucun setState n'est requis.
    _visited.add(_currentIndex);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const NewNoteIntent(),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            const SelectTabIntent(0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            const SelectTabIntent(1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            const SelectTabIntent(2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            const SelectTabIntent(3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            const SelectTabIntent(4),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true):
            const SelectTabIntent(5),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true):
            const SelectTabIntent(6),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true):
            const SelectTabIntent(7),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          NewNoteIntent: CallbackAction<NewNoteIntent>(
            onInvoke: (_) {
              _createNote();
              return null;
            },
          ),
          SelectTabIntent: CallbackAction<SelectTabIntent>(
            onInvoke: (intent) {
              _goToTab(intent.index);
              return null;
            },
          ),
          FocusSearchIntent: CallbackAction<FocusSearchIntent>(
            onInvoke: (_) {
              _goToTab(0);
              NotesScreenActions.focusSearch?.call();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: PopScope(
            canPop: false,
            onPopInvoked: (didPop) async {
              if (didPop) return;

              if (_currentIndex != 0) {
                // Si on n'est pas sur le premier onglet, on y retourne
                setState(() => _currentIndex = 0);
              } else if (defaultTargetPlatform == TargetPlatform.android) {
                // Android seulement. Sur iOS, une application ne se ferme pas
                // d'elle-meme : Apple refuse celles qui le font, et pour la
                // personne l'app semblerait simplement disparaitre. Le geste
                // de retour a la racine n'y fait donc rien, comme partout
                // ailleurs sur l'appareil. Sur bureau, c'est la fenetre qui
                // ferme.
                await SystemChannels.platform
                    .invokeMethod('SystemNavigator.pop');
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Le bandeau pousse le contenu au lieu de le recouvrir.
                // Pose en Positioned, il masquait l'en-tete de l'ecran :
                // sur telephone, le titre et l'avatar disparaissaient
                // derriere lui.
                final body = Column(
                  children: [
                    if (!isSignedIn) _buildConnectionBanner(context),
                    Expanded(
                      // IndexedStack : les onglets gardent leur etat, leur
                      // position de defilement et leurs donnees deja chargees.
                      child: IndexedStack(
                        index: _currentIndex,
                        children: [
                          for (var i = 0; i < _screens.length; i++)
                            if (_visited.contains(i))
                              _screens[i]
                            else
                              const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                );

                if (!Responsive.useSidebar(constraints.maxWidth)) {
                  return Scaffold(
                    body: body,
                    bottomNavigationBar: _buildNav(isDark),
                  );
                }

                final extended =
                    Responsive.useExtendedSidebar(constraints.maxWidth);

                return Scaffold(
                  body: Row(
                    children: [
                      StreamBuilder<int>(
                        stream: SharingService.instance
                            .watchUnreadReceivedNotesCount(),
                        builder: (context, snapshot) => AppSidebar(
                          currentIndex: _currentIndex,
                          onSelect: _goToTab,
                          extended: extended,
                          sharedBadge: snapshot.data ?? 0,
                          onCompose: _createNote,
                          footer: _buildSidebarFooter(extended, isDark),
                        ),
                      ),
                      Expanded(child: ClipRect(child: body)),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Pied de la barre laterale : le compte, et l'etat de synchronisation.
  Widget _buildSidebarFooter(bool extended, bool isDark) {
    if (extended) return _buildAccountRow(isDark);

    final (color, icon, _) = _syncVisual;
    return Tooltip(
      message: 'Synchronisation',
      waitDuration: const Duration(milliseconds: 420),
      child: GestureDetector(
        onTap: _showSyncInfoDialog,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _syncStatus == SyncStatus.syncing
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: color),
                    ),
                  )
                : Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }

  /// Ligne de compte du pied de barre : avatar, nom, etat de synchro.
  Widget _buildAccountRow(bool isDark) {
    final (color, icon, label) = _syncVisual;
    return _AccountCard(
      name: AuthService.instance.userName,
      userId: AuthService.instance.userId,
      signedIn: AuthService.instance.isSignedIn,
      syncColor: color,
      syncIcon: icon,
      syncLabel: label,
      syncing: _syncStatus == SyncStatus.syncing,
      isDark: isDark,
      onTap: AuthService.instance.isSignedIn
          ? _showSyncInfoDialog
          : () => Navigator.pushNamed(context, '/welcome'),
    );
  }

  (Color, IconData, String) get _syncVisual => switch (_syncStatus) {
        SyncStatus.syncing => (AppTheme.skyBlue, Icons.sync_rounded, 'Sync...'),
        SyncStatus.success => (
            AppTheme.skyBlue,
            Icons.cloud_done_rounded,
            'A jour'
          ),
        SyncStatus.error => (
            const Color(0xFFD1544B),
            Icons.error_outline_rounded,
            'Erreur'
          ),
        SyncStatus.offline => (
            const Color(0xFF9A7B3F),
            Icons.cloud_off_rounded,
            'Hors ligne'
          ),
        _ => (AppTheme.textMuted, Icons.cloud_queue_rounded, 'En attente'),
      };

  Widget _buildConnectionBanner(BuildContext context) {
    return Material(
      color: AppTheme.skyBlue,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/welcome'),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12,
            left: 20,
            right: 20,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_off_rounded,
                    size: 20, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Mode hors ligne',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text('Connectez-vous pour synchroniser',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncBadge() {
    final (color, icon, text) = _syncVisual;

    return GestureDetector(
      onTap: _showSyncInfoDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _syncStatus == SyncStatus.syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(text,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.info_outline_rounded,
                size: 14, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  void _showSyncInfoDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title;
    String description;
    IconData statusIcon;

    switch (_syncStatus) {
      case SyncStatus.syncing:
        title = 'Synchronisation en cours';
        description =
            'Vos notes sont en train d\'etre synchronisees avec le cloud. Patientez quelques instants.';
        statusIcon = Icons.sync_rounded;
        break;
      case SyncStatus.success:
        title = 'Synchronisation reussie';
        description =
            'Toutes vos notes sont a jour et sauvegardees dans le cloud. Vous pouvez y acceder depuis n\'importe quel appareil connecte a votre compte.';
        statusIcon = Icons.cloud_done_rounded;
        break;
      case SyncStatus.error:
        title = 'Erreur de synchronisation';
        description =
            'Une erreur est survenue lors de la synchronisation. Verifiez votre connexion internet et reessayez.';
        statusIcon = Icons.cloud_off_rounded;
        break;
      case SyncStatus.offline:
        title = 'Mode hors ligne';
        description =
            'Vous n\'etes pas connecte a internet. Vos notes sont sauvegardees localement et seront synchronisees automatiquement des que vous serez en ligne.';
        statusIcon = Icons.cloud_off_rounded;
        break;
      default:
        title = 'En attente';
        description =
            'La synchronisation demarrera automatiquement lorsque vous serez connecte.';
        statusIcon = Icons.cloud_queue_rounded;
    }

    final reportSummary = _lastSyncReport?.getSummary() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: AppTheme.skyBlue, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            if (reportSummary.isNotEmpty && _syncStatus != SyncStatus.syncing) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détails de la dernière opération:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reportSummary,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: _syncStatus == SyncStatus.error ? Colors.redAccent : (isDark ? Colors.white : AppTheme.textDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      size: 18, color: AppTheme.skyBlue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Connectez-vous pour synchroniser vos chroniques sur tous vos appareils.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_syncStatus == SyncStatus.error ||
              _syncStatus == SyncStatus.offline)
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _sync();
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reessayer'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  /// Destinations de la barre du bas.
  ///
  /// Six entrees : les Etincelles et les Citations s'atteignent depuis
  /// l'ecran Chroniques, ou deux boutons les attendent. Une barre de huit
  /// icones serait illisible sur un telephone.
  static const List<int> _barTabs = [0, 3, 4, 5, 6, 7];

  Widget _buildNav(bool isDark) {
    return ListenableBuilder(
      listenable: AccentColorService.instance,
      builder: (context, child) {
        final accentColor = AccentColorService.instance.accentColor;
        return Container(
          // La barre d'accueil de l'iPhone occupe le bas de l'ecran : sans
          // cette marge, la barre de navigation se glisse dessous et les deux
          // gestes se disputent les memes pixels. Sur un telephone sans
          // barre d'accueil, la valeur retombe a vingt.
          margin: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + (MediaQuery.viewPaddingOf(context).bottom * 0.5)
                .clamp(8.0, 26.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            // Meme matiere que le bandeau et la barre laterale : un degrade
            // et un reflet, plutot qu'un aplat qui ecrase la barre.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accentColor, Colors.white, 0.12)!,
                accentColor,
                Color.lerp(accentColor, Colors.black, 0.20)!,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.36),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final tab in _barTabs)
                if (tab == 3)
                  // Partage porte la pastille des notes recues.
                  StreamBuilder<int>(
                    stream:
                        SharingService.instance.watchUnreadReceivedNotesCount(),
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _buildNavItem(
                            tab,
                            AppDestination.all[tab].icon,
                            AppDestination.all[tab].activeIcon,
                            AppDestination.all[tab].label,
                            isDark,
                            accentColor,
                          ),
                          if (count > 0)
                            Positioned(
                              top: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                    minWidth: 16, minHeight: 16),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  count > 9 ? '9+' : '$count',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  )
                else
                  _buildNavItem(
                    tab,
                    AppDestination.all[tab].icon,
                    AppDestination.all[tab].activeIcon,
                    AppDestination.all[tab].label,
                    isDark,
                    accentColor,
                  ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon,
      String label, bool isDark, Color accentColor) {
    final selected = _currentIndex == index;

    return GestureDetector(
      onTap: () {
        if (_currentIndex == index) return;
        Tactile.selection();
        setState(() => _currentIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          vertical: 10,
          horizontal: selected ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 24,
              color: selected ? accentColor : Colors.white,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}


/// Pied de la barre laterale : qui est connecte, et ou en est la synchro.
///
/// L'ancienne version ne reagissait pas au survol alors qu'elle etait
/// cliquable. Une surface qui s'eclaire et un chevron qui avance disent
/// qu'il y a quelque chose derriere.
class _AccountCard extends StatefulWidget {
  final String? name;
  final String? userId;
  final bool signedIn;
  final Color syncColor;
  final IconData syncIcon;
  final String syncLabel;
  final bool syncing;
  final bool isDark;
  final VoidCallback onTap;

  const _AccountCard({
    required this.name,
    required this.userId,
    required this.signedIn,
    required this.syncColor,
    required this.syncIcon,
    required this.syncLabel,
    required this.syncing,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = AppTheme.skyBlue;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _hover
                ? accent.withValues(alpha: isDark ? 0.14 : 0.08)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.045)
                    : Colors.black.withValues(alpha: 0.028)),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: _hover
                  ? accent.withValues(alpha: 0.26)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              // Un anneau d'accent autour de l'avatar, et la pastille de
              // synchronisation posee dessus : l'etat se lit sur la personne.
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withValues(alpha: widget.signedIn ? 0.9 : 0.3),
                      Color.lerp(accent, Colors.white, 0.5)!
                          .withValues(alpha: widget.signedIn ? 0.9 : 0.3),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppTheme.surfaceDark : Colors.white,
                  ),
                  child: UserAvatar(
                    displayName: widget.name ?? '?',
                    userId: widget.userId,
                    radius: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.signedIn
                          ? (widget.name ?? 'Mon compte')
                          : 'Hors ligne',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        widget.syncing
                            ? SizedBox(
                                width: 9,
                                height: 9,
                                child: CircularProgressIndicator(
                                    strokeWidth: 1.6, color: widget.syncColor),
                              )
                            : Icon(widget.syncIcon,
                                size: 11, color: widget.syncColor),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            widget.syncLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: widget.syncColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                duration: AppMotion.fast,
                curve: AppMotion.enter,
                offset: Offset(_hover ? 0.18 : 0, 0),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: _hover
                      ? accent
                      : (isDark
                          ? AppTheme.textMutedDark.withValues(alpha: 0.6)
                          : AppTheme.textMuted.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
