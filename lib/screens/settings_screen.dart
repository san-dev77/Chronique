import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_launcher_preview.dart';
import '../services/backup_service.dart';
import '../services/note_service.dart';
import '../services/image_migration_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/memory_notification_service.dart';
import '../services/background_task_service.dart';
import '../services/accent_color_service.dart';
import '../services/theme_service.dart';
import '../services/sharing_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isRepairing = false;
  bool _isCleaning = false;
  bool _isSyncing = false; // Pour la sync manuelle
  String? _firestoreName; // Nom recupere de Firestore si Auth est vide
  bool _isSendingNotif = false;
  bool _backgroundTaskEnabled = false;
  DateTime? _lastBackgroundRun;

  @override
  void initState() {
    super.initState();
    _loadBackgroundTaskStatus();
    _loadFirestoreProfile();
  }

  Future<void> _loadBackgroundTaskStatus() async {
    final enabled = await BackgroundTaskService.instance.isTaskEnabled();
    final lastRun = await BackgroundTaskService.instance.getLastRunTime();
    if (mounted) {
      setState(() {
        _backgroundTaskEnabled = enabled;
        _lastBackgroundRun = lastRun;
      });
    }
  }

  Future<void> _loadFirestoreProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          _firestoreName = (doc.data() as Map<String, dynamic>?)?['displayName'];
        });
      }
    } catch (e) {
      debugPrint('Err loadFirestoreProfile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = AccentColorService.instance.accentColor;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
          title: Text(
            'Parametres',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textDark,
              letterSpacing: -0.5,
            ),
          ),
          bottom: TabBar(
            indicatorColor: accentColor,
            labelColor: accentColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'PROFIL', icon: Icon(Icons.person_rounded, size: 20)),
              Tab(text: 'DESIGN', icon: Icon(Icons.palette_rounded, size: 20)),
              Tab(text: 'OUTILS', icon: Icon(Icons.build_circle_rounded, size: 20)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildProfileTab(isDark),
            _buildAppearanceTab(isDark),
            _buildMaintenanceTab(isDark),
          ],
        ),
      ),
    );
  }

  // --- TABS ---

  Widget _buildProfileTab(bool isDark) {
    final user = AuthService.instance.currentUser;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person_rounded, size: 64, color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('Connectez-vous pour voir votre profil'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // User Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AppTheme.skyBlue.withOpacity(0.12),
                child: Text(
                  _getInitial(AuthService.instance.userName),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.skyBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                (AuthService.instance.userName?.isNotEmpty == true 
                    ? AuthService.instance.userName! 
                    : (_firestoreName ?? 'Utilisateur')),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                AuthService.instance.userEmail ?? '',
                style: TextStyle(color: isDark ? Colors.grey : AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMiniAction(
                    icon: Icons.edit_rounded,
                    label: 'Modifier',
                    onTap: _showEditNameDialog,
                  ),
                  const SizedBox(width: 12),
                  _buildMiniAction(
                    icon: Icons.sync_rounded,
                    label: 'Sync',
                    onTap: _manualSync,
                    isLoading: _isSyncing,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        _buildActionTile(
          icon: Icons.cloud_done_rounded,
          iconColor: Colors.green,
          title: 'Etat de synchronisation',
          subtitle: 'Vos notes sont en securite',
          trailing: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          onTap: () {},
        ),
        
        const SizedBox(height: 12),
        
        _buildActionTile(
          icon: Icons.logout_rounded,
          iconColor: Colors.redAccent,
          title: 'Deconnexion',
          subtitle: 'Sortir de votre compte',
          onTap: _handleSignOut,
        ),
        
        const SizedBox(height: 32),
        Center(
          child: Text(
            'ID: ${AuthService.instance.userId}',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSectionTitle('Theme & Style'),
        _buildSwitchTile(
          icon: Icons.dark_mode_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Theme Sombre',
          subtitle: 'Reposant pour les yeux',
          value: isDark,
          onChanged: (v) async {
            await ThemeService.instance.setDarkMode(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildAccentColorPicker(isDark),
        const SizedBox(height: 32),
        _buildSectionTitle('Aperçu du Launcher'),
        const Center(child: AppLauncherPreview()),
      ],
    );
  }

  Widget _buildMaintenanceTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildBackgroundTaskStatus(isDark),
        const SizedBox(height: 24),
        
        _buildSectionTitle('Notifications Souvenirs'),
        _buildNotificationsContent(isDark),
        
        const SizedBox(height: 32),
        _buildSectionTitle('Images'),
        _buildImagesContent(isDark),
        
        const SizedBox(height: 32),
        _buildSectionTitle('Sauvegarde Manuelle (Offline)'),
        _buildBackupContent(isDark),

        const SizedBox(height: 40),
        const Center(child: Text('Note Box v1.1.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
        const SizedBox(height: 20),
      ],
    );
  }

  // --- HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMiniAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.skyBlue.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (isLoading)
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 16, color: AppTheme.skyBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.skyBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundTaskStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundTaskEnabled ? AppTheme.skyBlue.withOpacity(0.08) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _backgroundTaskEnabled ? AppTheme.skyBlue.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            _backgroundTaskEnabled ? Icons.bolt_rounded : Icons.bolt_outlined,
            color: _backgroundTaskEnabled ? AppTheme.skyBlue : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _backgroundTaskEnabled ? 'Tache active' : 'Tache inactive',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Dernier passage: ${BackgroundTaskService.instance.formatRelativeTime(_lastBackgroundRun)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLoading = false,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: isLoading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : trailing ?? const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
        onTap: isLoading ? null : onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: iconColor, size: 22),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.skyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildNotificationsContent(bool isDark) {
    final notifService = MemoryNotificationService.instance;
    return Column(
      children: [
        _buildSwitchTile(
          icon: Icons.edit_note_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Confirmations directes',
          subtitle: 'Alerte lors de la creation',
          value: notifService.notifyOnCreate,
          onChanged: (v) async {
            await notifService.setNotifyOnCreate(v);
            setState(() {});
          },
        ),
        const SizedBox(height: 8),
        _buildSwitchTile(
          icon: Icons.auto_awesome_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Souvenirs auto',
          subtitle: 'S\'affiche dans le temps',
          value: notifService.memoriesEnabled,
          onChanged: (v) async {
            await notifService.setMemoriesEnabled(v);
            if (v) {
              await BackgroundTaskService.instance.startMemoriesTask();
            } else {
              await BackgroundTaskService.instance.stopMemoriesTask();
            }
            await _loadBackgroundTaskStatus();
            setState(() {});
          },
        ),
        if (notifService.memoriesEnabled) ...[
          const SizedBox(height: 8),
          _buildActionTile(
            icon: Icons.schedule_rounded,
            iconColor: AppTheme.skyBlue,
            title: 'Heure de rappel',
            subtitle: notifService.memoriesTimeFormatted,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: notifService.memoriesHour, minute: notifService.memoriesMinute),
              );
              if (time != null) {
                await notifService.setMemoriesTime(time.hour, time.minute);
                setState(() {});
              }
            },
          ),
        ],
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.notifications_active_rounded,
          iconColor: Colors.orange,
          title: 'Tester les notifications',
          subtitle: 'Verifier le bon fonctionnement',
          isLoading: _isSendingNotif,
          onTap: _testNotification,
        ),
      ],
    );
  }

  Widget _buildImagesContent(bool isDark) {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.build_rounded,
          iconColor: Colors.blueAccent,
          title: 'Reparer le catalogue',
          subtitle: 'Corriger les liens casses',
          isLoading: _isRepairing,
          onTap: _repairImages,
        ),
        _buildActionTile(
          icon: Icons.cleaning_services_rounded,
          iconColor: Colors.grey,
          title: 'Purge des fichiers',
          subtitle: 'Supprimer les images orphelines',
          isLoading: _isCleaning,
          onTap: _cleanupOrphanImages,
        ),
      ],
    );
  }

  Widget _buildBackupContent(bool isDark) {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.upload_rounded,
          iconColor: accentColor,
          title: 'Exporter Backup',
          subtitle: 'Sauvegarde complete (.zip)',
          isLoading: _isExporting,
          onTap: _exportNotes,
        ),
        _buildActionTile(
          icon: Icons.download_rounded,
          iconColor: accentColor,
          title: 'Importer Backup',
          subtitle: 'Restaurer une sauvegarde',
          isLoading: _isImporting,
          onTap: _importNotes,
        ),
      ],
    );
  }

  Widget _buildAccentColorPicker(bool isDark) {
    final currentColor = AccentColorService.instance.accentColor;
    final colors = AccentColorService.availableColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Couleur d\'accentuation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final option = colors[index];
                final isSelected = currentColor.value == option.color.value;
                return GestureDetector(
                  onTap: () async {
                    await AccentColorService.instance.setAccentColor(option.color);
                    setState(() {});
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: isDark ? Colors.white : Colors.black, width: 3)
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(color: option.color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)
                      ],
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ACTIONS ---

  String _getInitial(String? name) => (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
  Color get accentColor => AccentColorService.instance.accentColor;

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      await CloudSyncService.instance.syncAll();
      await SharingService.instance.registerCurrentUser(); // Re-sync profile too
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Synchronisation reussie !')));
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Erreur Sync', e.toString());
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text('Voulez-vous vraiment vous deconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ANNULER')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DECONNEXION'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
    }
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: AuthService.instance.userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier votre nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Nom d\'affichage', border: OutlineInputBorder()),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Enregistrer')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await AuthService.instance.updateDisplayName(newName);
        await SharingService.instance.registerCurrentUser(name: newName); // Sync to Firestore with explicit name
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nom mis à jour avec succès !')));
      } catch (e) {
        if (!mounted) return;
        _showErrorDialog('Erreur', e.toString());
      }
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isSendingNotif = true);
    try {
      await MemoryNotificationService.instance.sendTestNotification();
    } finally {
      if (mounted) setState(() => _isSendingNotif = false);
    }
  }

  Future<void> _repairImages() async {
    setState(() => _isRepairing = true);
    final report = await ImageMigrationService.instance.repairAllImages();
    if (mounted) {
      setState(() => _isRepairing = false);
      _showReportDialog('Reparation terminee', report.getSummary());
    }
  }

  Future<void> _cleanupOrphanImages() async {
    setState(() => _isCleaning = true);
    final count = await ImageMigrationService.instance.cleanupOrphanImages();
    if (mounted) {
      setState(() => _isCleaning = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count image(s) orpheline(s) supprimee(s)')));
    }
  }

  Future<void> _exportNotes() async {
    setState(() => _isExporting = true);
    try {
      final path = await BackupService.instance.exportToSingleFile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sauvegarde effectuee dans : $path')),
        );
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Erreur Export', e.toString());
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _importNotes() async {
    // Comme on n'a pas de file_picker, on demande le chemin via un dialog simple
    final controller = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer une sauvegarde'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Chemin complet du fichier .json',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ANNULER')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('IMPORTER')),
        ],
      ),
    );

    if (path == null || path.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final count = await BackupService.instance.importFromSingleFile(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count note(s) importee(s) !')),
        );
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Erreur Import', e.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showReportDialog(String title, String summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(summary),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
      ),
    );
  }
}
