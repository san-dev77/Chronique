import 'package:flutter/material.dart';
import 'notes_screen.dart';
import 'favorites_screen.dart';
import 'memories_screen.dart';
import 'settings_screen.dart';
import 'shared_notes_screen.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/connectivity_service.dart';
import '../services/accent_color_service.dart';
import '../theme/app_theme.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  final int initialTab;

  const MainScreen({super.key, this.initialTab = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

enum SyncStatus { idle, syncing, success, offline, error }

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  SyncStatus _syncStatus = SyncStatus.idle;
  bool _isConnected = true;
  StreamSubscription? _connectivitySub;

  final _screens = const [
    NotesScreen(),
    SharedNotesScreen(),
    MemoriesScreen(),
    FavoritesScreen(),
    SettingsScreen()
  ];

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
      await CloudSyncService.instance.syncAll();
      if (mounted) setState(() => _syncStatus = SyncStatus.success);
    } catch (_) {
      if (mounted) setState(() => _syncStatus = SyncStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSignedIn = AuthService.instance.isSignedIn;

    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],
          // Banner connexion
          if (!isSignedIn)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildConnectionBanner(context),
            ),
          // Badge sync (Affiche seulement en cas d'erreur ou offline)
          if (isSignedIn && (_syncStatus == SyncStatus.error || _syncStatus == SyncStatus.offline))
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: _buildSyncBadge(),
            ),
        ],
      ),
      bottomNavigationBar: _buildNav(isDark),
    );
  }

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
              const Expanded(
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
    final (color, icon, text) = switch (_syncStatus) {
      SyncStatus.syncing => (AppTheme.skyBlue, Icons.sync_rounded, 'Sync...'),
      SyncStatus.success => (
          AppTheme.skyBlue,
          Icons.cloud_done_rounded,
          'A jour'
        ),
      SyncStatus.error => (AppTheme.skyBlue, Icons.cloud_off_rounded, 'Erreur'),
      SyncStatus.offline => (
          AppTheme.skyBlue,
          Icons.cloud_off_rounded,
          'Hors ligne'
        ),
      _ => (AppTheme.textMuted, Icons.cloud_queue_rounded, 'En attente'),
    };

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
                      'Connectez-vous pour synchroniser vos notes sur tous vos appareils.',
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

  Widget _buildNav(bool isDark) {
    return ListenableBuilder(
      listenable: AccentColorService.instance,
      builder: (context, child) {
        final accentColor = AccentColorService.instance.accentColor;
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.note_alt_outlined, Icons.note_alt_rounded,
                  'Notes', isDark, accentColor),
              _buildNavItem(1, Icons.people_outline_rounded, Icons.people_rounded,
                  'Partage', isDark, accentColor),
              _buildNavItem(2, Icons.auto_awesome_outlined,
                  Icons.auto_awesome_rounded, 'Souvenirs', isDark, accentColor),
              _buildNavItem(3, Icons.favorite_outline_rounded,
                  Icons.favorite_rounded, 'Favoris', isDark, accentColor),
              _buildNavItem(4, Icons.settings_outlined, Icons.settings_rounded,
                  'Réglages', isDark, accentColor),
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
      onTap: () => setState(() => _currentIndex = index),
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
