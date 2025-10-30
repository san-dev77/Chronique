import 'package:flutter/material.dart';
import 'notes_screen.dart';
import 'favorites_screen.dart';
import 'settings_screen.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/connectivity_service.dart';
import 'dart:async';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

enum SyncStatus { idle, syncing, success, offline, error }

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  SyncStatus _syncStatus = SyncStatus.idle;
  bool _isConnected = true;
  StreamSubscription? _connectivitySubscription;

  final List<Widget> _screens = [
    const NotesScreen(),
    const FavoritesScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Écouter les changements de connectivité
    _isConnected = ConnectivityService.instance.isConnected;
    _connectivitySubscription =
        ConnectivityService.instance.connectivityStream.listen((connected) {
      setState(() => _isConnected = connected);

      // Si connexion revenue et utilisateur connecté, sync auto
      if (connected && AuthService.instance.isSignedIn) {
        _autoSyncOnStart();
      }
    });

    // Sync automatique au démarrage si connecté
    _autoSyncOnStart();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _autoSyncOnStart() async {
    if (!AuthService.instance.isSignedIn) return;
    if (!_isConnected) {
      setState(() => _syncStatus = SyncStatus.offline);
      return;
    }

    setState(() => _syncStatus = SyncStatus.syncing);

    try {
      await CloudSyncService.instance.syncAll();
      if (mounted) {
        setState(() => _syncStatus = SyncStatus.success);
      }
    } catch (e) {
      print('Erreur sync auto démarrage: $e');
      if (mounted) {
        setState(() => _syncStatus = SyncStatus.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = AuthService.instance.isSignedIn;

    return Scaffold(
      body: Stack(
        children: [
          _screens[_currentIndex],

          // Bannière "Connectez-vous" si pas de compte
          if (!isSignedIn)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(context, '/welcome');
                  },
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 8,
                      bottom: 12,
                      left: 16,
                      right: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade600,
                          Colors.orange.shade500,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.cloud_off,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Notes locales uniquement',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Connectez-vous pour synchroniser',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Indicateur de sync en haut à droite (si connecté)
          if (isSignedIn)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: _buildSyncBadge(),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor:
                Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.note_alt_outlined),
                activeIcon: Icon(Icons.note_alt),
                label: 'Notes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_outline),
                activeIcon: Icon(Icons.favorite),
                label: 'Favoris',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Paramètres',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncBadge() {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (!_isConnected) {
      // Pas de connexion internet
      badgeColor = Colors.orange.shade600;
      badgeIcon = Icons.cloud_off;
      badgeText = 'Hors ligne';
    } else {
      switch (_syncStatus) {
        case SyncStatus.syncing:
          badgeColor = Colors.blue.shade600;
          badgeIcon = Icons.sync;
          badgeText = 'Sync...';
          break;
        case SyncStatus.success:
          badgeColor = Colors.green.shade600;
          badgeIcon = Icons.cloud_done;
          badgeText = 'Sync OK';
          break;
        case SyncStatus.error:
          badgeColor = Colors.red.shade600;
          badgeIcon = Icons.cloud_off;
          badgeText = 'Erreur';
          break;
        case SyncStatus.offline:
          badgeColor = Colors.orange.shade600;
          badgeIcon = Icons.cloud_off;
          badgeText = 'Hors ligne';
          break;
        default:
          badgeColor = Colors.grey.shade600;
          badgeIcon = Icons.cloud_queue;
          badgeText = 'En attente';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_syncStatus == SyncStatus.syncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else
            Icon(
              badgeIcon,
              size: 16,
              color: Colors.white,
            ),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
