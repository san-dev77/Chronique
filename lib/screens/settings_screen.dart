import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../services/image_base64_service.dart';
import '../utils/image_picker_helper.dart';
import '../services/image_crop_service.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/user_avatar.dart';
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
  String? _profilePhotoBase64;
  int? _profileColor;
  bool _isSendingNotif = false;
  bool _backgroundTaskEnabled = false;
  DateTime? _lastBackgroundRun;
  String? _lastNotifDate;
  String? _lastNotifReason;
  String? _lastWorkerRunRaw;
  String? _nextScheduledNotif;

  @override
  void initState() {
    super.initState();
    _loadBackgroundTaskStatus();
    _loadFirestoreProfile();
  }

  Future<void> _loadBackgroundTaskStatus() async {
    final enabled = await BackgroundTaskService.instance.isTaskEnabled();
    final lastRun = await BackgroundTaskService.instance.getLastRunTime();

    final prefs = await SharedPreferences.getInstance();
    final notifDate = prefs.getString('last_notif_date');
    final notifReason = prefs.getString('last_notif_reason');
    final workerRunRaw = prefs.getString('last_worker_run');
    final nextScheduled = prefs.getString('next_scheduled_notif');

    if (mounted) {
      setState(() {
        _backgroundTaskEnabled = enabled;
        _lastBackgroundRun = lastRun;
        _lastNotifDate = notifDate;
        _lastNotifReason = notifReason;
        _lastWorkerRunRaw = workerRunRaw;
        _nextScheduledNotif = nextScheduled;
      });
    }
  }

  Future<void> _loadFirestoreProfile() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>?;
        setState(() {
          _firestoreName = data?['displayName'];
          _profilePhotoBase64 = data?['photoBase64'];
          _profileColor = data?['profileColor'];
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
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'PROFIL', icon: Icon(Icons.person_rounded, size: 20)),
              Tab(text: 'DESIGN', icon: Icon(Icons.palette_rounded, size: 20)),
              Tab(
                  text: 'OUTILS',
                  icon: Icon(Icons.build_circle_rounded, size: 20)),
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
            Icon(Icons.lock_person_rounded,
                size: 64, color: Colors.grey.withOpacity(0.3)),
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
              GestureDetector(
                onTap: _pickProfileImage,
                child: Stack(
                  children: [
                    UserAvatar(
                      displayName: AuthService.instance.userName ?? 'U',
                      photoBase64: _profilePhotoBase64,
                      photoUrl: AuthService.instance.currentUser?.photoURL,
                      profileColor: _profileColor,
                      radius: 50,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _pickProfileImage,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Changer la photo'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.skyBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                (AuthService.instance.userName?.isNotEmpty == true
                    ? AuthService.instance.userName!
                    : (_firestoreName ?? 'Utilisateur')),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              Text(
                AuthService.instance.userEmail ?? '',
                style:
                    TextStyle(color: isDark ? Colors.grey : AppTheme.textMuted),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildMiniAction(
                    icon: Icons.palette_rounded,
                    label: 'Couleur',
                    onTap: _showProfileColorPicker,
                  ),
                  const SizedBox(width: 12),
                  _buildMiniAction(
                    icon: Icons.edit_rounded,
                    label: 'Nom',
                    onTap: _showEditNameDialog,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildMiniAction(
                icon: Icons.sync_rounded,
                label: 'Synchronisation Cloud',
                onTap: _manualSync,
                isLoading: _isSyncing,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        _buildActionTile(
          icon: Icons.cloud_done_rounded,
          iconColor: Colors.green,
          title: 'Etat de synchronisation',
          subtitle: 'Vos chroniques sont en securite',
          trailing: const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 20),
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
        _buildSectionTitle('Aperçu de l\'icone'),
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
        _buildSectionTitle('Rapport de Diagnostic'),
        _buildDiagnosticSection(isDark),
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
        const Center(
            child: Text('Chronique Box v1.2.0',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
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
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
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
        color: _backgroundTaskEnabled
            ? AppTheme.skyBlue.withOpacity(0.08)
            : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _backgroundTaskEnabled
                ? AppTheme.skyBlue.withOpacity(0.2)
                : Colors.grey.withOpacity(0.1)),
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
                  _backgroundTaskEnabled
                      ? 'Tâche de fond active'
                      : 'Tâche de fond inactive',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _backgroundTaskEnabled
                          ? (isDark ? Colors.greenAccent : Colors.green[800])
                          : (isDark ? Colors.grey[400] : Colors.grey[700]),
                      fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Auto-souvenirs: ${BackgroundTaskService.instance.formatRelativeTime(_lastBackgroundRun)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w500),
                ),
                if (_lastNotifDate != null)
                  Text(
                    'Dernière alerte: $_lastNotifDate',
                    style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.black87,
                        fontWeight: FontWeight.w500),
                  ),
                if (_lastWorkerRunRaw != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Pulsation système: ${BackgroundTaskService.instance.formatRelativeTime(DateTime.tryParse(_lastWorkerRunRaw!))}',
                      style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(isDark ? 0.1 : 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Les chroniques sont vérifiées toutes les 15 minutes (minimum Android). Les Souvenirs sont envoyés une seule fois à l\'heure choisie.',
                          style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.amber[200]
                                  : Colors.amber[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_lastNotifReason?.contains('envoyé') == true)
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_rounded,
                  color: (_lastNotifReason?.contains('envoyé') == true)
                      ? Colors.green
                      : Colors.orange,
                  size: 20),
              const SizedBox(width: 8),
              const Text(
                'État du système',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDiagnosticRow(
              'Check Chroniques (Fréquent)',
              _lastWorkerRunRaw != null
                  ? BackgroundTaskService.instance
                      .formatRelativeTime(DateTime.tryParse(_lastWorkerRunRaw!))
                  : 'Jamais',
              isDark),
          _buildDiagnosticRow('Check Souvenirs (Quotidien)',
              _lastNotifReason ?? 'En attente', isDark,
              isSuccess: _lastNotifReason?.contains('envoyé') == true),
          if (_nextScheduledNotif != null)
            _buildDiagnosticRow(
              'Prochain Souvenir',
              BackgroundTaskService.instance
                  .formatRelativeTime(DateTime.tryParse(_nextScheduledNotif!)),
              isDark,
              isSuccess: true,
            ),
          const SizedBox(height: 12),
          _buildMiniAction(
            icon: Icons.refresh_rounded,
            label: 'Actualiser le diagnostic',
            onTap: _loadBackgroundTaskStatus,
          ),
          const SizedBox(width: 8),
          _buildMiniAction(
            icon: Icons.play_circle_filled_rounded,
            label: 'Forcer la vérification (Test)',
            onTap: () async {
              setState(() => _isSyncing = true);
              await BackgroundTaskService.instance.debugForceRun();
              await _loadBackgroundTaskStatus();
              if (mounted) {
                setState(() => _isSyncing = false);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Vérification forcée terminée !')));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosticRow(String label, String value, bool isDark,
      {bool? isSuccess}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSuccess == true
                      ? (isDark ? Colors.greenAccent : Colors.green[700])
                      : (isSuccess == false
                          ? (isDark ? Colors.orangeAccent : Colors.orange[800])
                          : (isDark ? Colors.white70 : Colors.black87)),
                )),
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
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : trailing ??
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: Colors.grey),
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
        title: Text(title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        _buildBackgroundTaskStatus(isDark),
        const SizedBox(height: 12),
        _buildMiniAction(
          icon: Icons.flash_on_rounded,
          label: 'Simuler passage du Worker',
          onTap: () async {
            await BackgroundTaskService.instance.debugForceRun();
            await _loadBackgroundTaskStatus();
            setState(() {});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Simulation du Worker terminée. Vérifiez vos notifications !')),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        _buildSwitchTile(
          icon: Icons.edit_note_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Confirmations directes',
          subtitle: 'Alerte lors de la création d\'une note',
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
          subtitle: 'Découvrir d\'anciennes chroniques',
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
            icon: Icons.access_time_rounded,
            iconColor: AppTheme.skyBlue,
            title: 'Heure de notification',
            subtitle: 'Programmé pour ${notifService.memoriesTimeFormatted}',
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: notifService.memoriesHour,
                    minute: notifService.memoriesMinute),
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
          const Text('Couleur d\'accentuation',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                    await AccentColorService.instance
                        .setAccentColor(option.color);
                    setState(() {});
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: option.color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: isDark ? Colors.white : Colors.black,
                              width: 3)
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                              color: option.color.withOpacity(0.4),
                              blurRadius: 10,
                              spreadRadius: 2)
                      ],
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
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

  String _getInitial(String? name) =>
      (name?.isNotEmpty == true) ? name![0].toUpperCase() : '?';
  Color get accentColor => AccentColorService.instance.accentColor;

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      await CloudSyncService.instance.syncAll();
      await SharingService.instance
          .registerCurrentUser(); // Re-sync profile too
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synchronisation reussie !')));
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ANNULER')),
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
    final controller =
        TextEditingController(text: AuthService.instance.userName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier votre nom'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              hintText: 'Nom d\'affichage', border: OutlineInputBorder()),
          autofocus: true,
          maxLength: 30,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Enregistrer')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      try {
        await AuthService.instance.updateDisplayName(newName);
        await SharingService.instance.registerCurrentUser(
            name: newName); // Sync to Firestore with explicit name
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nom mis à jour avec succès !')));
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

  Future<void> _pickProfileImage() async {
    final String? finalPath =
        await ImagePickerHelper.pickAndOptionallyCrop(context, isProfile: true);

    if (finalPath != null) {
      setState(() => _isSyncing = true);
      try {
        // Encodage
        final base64 =
            await ImageBase64Service.instance.encodeImageToBase64(finalPath);
        if (base64 != null) {
          await SharingService.instance.updateProfileData(photoBase64: base64);
          setState(() {
            _profilePhotoBase64 = base64;
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Photo de profil mise à jour !')));
        }
      } catch (e) {
        _showErrorDialog('Erreur Image', e.toString());
      } finally {
        setState(() => _isSyncing = false);
      }
    }
  }

  void _showProfileColorPicker() {
    final colors = [
      AppTheme.skyBlue,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.blueGrey,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Couleur d\'avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 100,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final color = colors[index];
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await SharingService.instance
                          .updateProfileData(profileColor: color.value);
                      setState(() {
                        _profileColor = color.value;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.3), blurRadius: 8)
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await SharingService.instance
                    .updateProfileData(profileColor: null);
                setState(() => _profileColor = null);
              },
              child: const Text('Reinitialiser par defaut'),
            ),
          ],
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count image(s) orpheline(s) supprimee(s)')));
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
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ANNULER')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('IMPORTER')),
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
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  void _showReportDialog(String title, String summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(summary),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'))
        ],
      ),
    );
  }
}
