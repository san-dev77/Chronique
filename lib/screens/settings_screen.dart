import 'package:flutter/material.dart';
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
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isRepairing = false;
  bool _isCleaning = false;
  bool _isSyncing = false;
  bool _isSendingNotif = false;
  bool _backgroundTaskEnabled = false;
  DateTime? _lastBackgroundRun;

  @override
  void initState() {
    super.initState();
    _loadBackgroundTaskStatus();
  }

  Future<void> _loadBackgroundTaskStatus() async {
    final enabled = await BackgroundTaskService.instance.isTaskEnabled();
    final lastRun = await BackgroundTaskService.instance.getLastRunTime();
    setState(() {
      _backgroundTaskEnabled = enabled;
      _lastBackgroundRun = lastRun;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  24, MediaQuery.of(context).padding.top + 20, 24, 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.skyBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.settings_rounded,
                        size: 26, color: AppTheme.skyBlue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parametres',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? AppTheme.textLight : AppTheme.textDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configuration de l\'application',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.textMutedDark
                                : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Tache de fond status
                _buildBackgroundTaskStatus(isDark),
                const SizedBox(height: 20),

                // Notifications
                _buildSection(
                  isDark: isDark,
                  icon: Icons.notifications_rounded,
                  iconColor: AppTheme.skyBlue,
                  title: 'Notifications',
                  subtitle: 'Souvenirs et alertes',
                  children: [
                    _buildNotificationsContent(isDark),
                  ],
                ),
                const SizedBox(height: 16),

                // Apparence
                _buildSection(
                  isDark: isDark,
                  icon: Icons.palette_rounded,
                  iconColor: AppTheme.skyBlue,
                  title: 'Apparence',
                  subtitle: 'Personnaliser l\'interface',
                  children: [
                    _buildSwitchTile(
                      icon: Icons.dark_mode_rounded,
                      iconColor: AppTheme.skyBlue,
                      title: 'Theme sombre',
                      subtitle:
                          ThemeService.instance.themeMode == ThemeMode.system
                              ? 'Suit le systeme'
                              : (isDark ? 'Active' : 'Desactive'),
                      value: isDark,
                      onChanged: (v) async {
                        await ThemeService.instance.setDarkMode(v);
                        setState(() {});
                      },
                    ),
                    Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : Colors.grey.shade200),
                    _buildAccentColorPicker(isDark),
                  ],
                ),
                const SizedBox(height: 16),

                // Images
                _buildSection(
                  isDark: isDark,
                  icon: Icons.image_rounded,
                  iconColor: AppTheme.skyBlue,
                  title: 'Gestion des images',
                  subtitle: 'Reparer et optimiser',
                  children: [
                    _buildImagesContent(isDark),
                  ],
                ),
                const SizedBox(height: 16),

                // Cloud sync
                if (AuthService.instance.isSignedIn) ...[
                  _buildSection(
                    isDark: isDark,
                    icon: Icons.cloud_rounded,
                    iconColor: AppTheme.skyBlue,
                    title: 'Synchronisation',
                    subtitle: AuthService.instance.userEmail ?? 'Connecte',
                    children: [
                      _buildCloudContent(isDark),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Sauvegarde
                _buildSection(
                  isDark: isDark,
                  icon: Icons.save_rounded,
                  iconColor: AppTheme.skyBlue,
                  title: 'Sauvegarde',
                  subtitle: 'Exporter et importer',
                  children: [
                    _buildBackupContent(isDark),
                  ],
                ),
                const SizedBox(height: 16),

                // A propos
                _buildSection(
                  isDark: isDark,
                  icon: Icons.info_rounded,
                  iconColor: AppTheme.skyBlue,
                  title: 'A propos',
                  subtitle: 'Note Box v1.0.0',
                  children: [
                    _buildStatsTile(isDark),
                    const SizedBox(height: 8),
                    const Center(child: AppLauncherPreview()),
                    const SizedBox(height: 16),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour le status de la tache de fond
  Widget _buildBackgroundTaskStatus(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _backgroundTaskEnabled
              ? [
                  AppTheme.skyBlue.withOpacity(0.15),
                  AppTheme.skyBlue.withOpacity(0.05)
                ]
              : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _backgroundTaskEnabled
              ? AppTheme.skyBlue.withOpacity(0.3)
              : Colors.grey.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _backgroundTaskEnabled ? AppTheme.skyBlue : Colors.grey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _backgroundTaskEnabled
                  ? Icons.sync_rounded
                  : Icons.sync_disabled_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _backgroundTaskEnabled
                      ? 'Tache de fond active'
                      : 'Tache de fond inactive',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _backgroundTaskEnabled
                      ? 'Derniere execution: ${BackgroundTaskService.instance.formatRelativeTime(_lastBackgroundRun)}'
                      : 'Activez les notifications pour demarrer',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (_backgroundTaskEnabled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Active',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Section container
  Widget _buildSection({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          ...children,
        ],
      ),
    );
  }

  // Switch tile
  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SwitchListTile(
      secondary: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : Colors.grey.shade600,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.skyBlue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }

  // Action tile
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
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.white70 : Colors.grey.shade600,
        ),
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : trailing ??
              Icon(Icons.chevron_right_rounded,
                  size: 22, color: isDark ? Colors.white54 : Colors.grey),
      onTap: isLoading ? null : onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  // Notifications content
  Widget _buildNotificationsContent(bool isDark) {
    final notifService = MemoryNotificationService.instance;
    final memoryStats = notifService.getMemoryStats();

    return Column(
      children: [
        // Toggle notification creation
        _buildSwitchTile(
          icon: Icons.edit_note_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Notification a la creation',
          subtitle: 'Confirmer chaque nouvelle note',
          value: notifService.notifyOnCreate,
          onChanged: (v) async {
            await notifService.setNotifyOnCreate(v);
            setState(() {});
          },
        ),

        Divider(
            height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),

        // Toggle souvenirs + tache de fond
        _buildSwitchTile(
          icon: Icons.auto_awesome_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Notifications souvenirs',
          subtitle:
              _backgroundTaskEnabled ? 'Actif - 2x par jour' : 'Desactive',
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

        // Heure de notification
        if (notifService.memoriesEnabled) ...[
          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          _buildActionTile(
            icon: Icons.schedule_rounded,
            iconColor: AppTheme.skyBlue,
            title: 'Heure preferee',
            subtitle: notifService.memoriesTimeFormatted,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                notifService.memoriesTimeFormatted,
                style: TextStyle(
                  color: AppTheme.skyBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: notifService.memoriesHour,
                  minute: notifService.memoriesMinute,
                ),
              );
              if (time != null) {
                await notifService.setMemoriesTime(time.hour, time.minute);
                setState(() {});
              }
            },
          ),
        ],

        // Periodes disponibles
        if (memoryStats.isNotEmpty) ...[
          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Souvenirs disponibles',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: memoryStats.entries.map((e) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e.key.replaceAll('...', ''),
                            style: TextStyle(
                                fontSize: 12, color: AppTheme.skyBlue),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.skyBlue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${e.value}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        Divider(
            height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),

        // Test button
        _buildActionTile(
          icon: Icons.send_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Tester une notification',
          subtitle: 'Envoyer un souvenir maintenant',
          isLoading: _isSendingNotif,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.skyBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Test',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          onTap: _testNotification,
        ),
      ],
    );
  }

  // Images content
  Widget _buildImagesContent(bool isDark) {
    return Column(
      children: [
        FutureBuilder<ImageAnalysisReport>(
          future: ImageMigrationService.instance.analyzeImages(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final report = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: report.hasIssues()
                      ? AppTheme.skyBlue.withOpacity(0.1)
                      : AppTheme.skyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      report.hasIssues()
                          ? Icons.warning_rounded
                          : Icons.check_circle_rounded,
                      color: report.hasIssues()
                          ? AppTheme.skyBlue
                          : AppTheme.skyBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        report.getSummary(),
                        style: TextStyle(
                          fontSize: 12,
                          color: report.hasIssues()
                              ? AppTheme.skyBlue
                              : AppTheme.skyBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        _buildActionTile(
          icon: Icons.build_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Reparer les images',
          subtitle: 'Corriger les chemins invalides',
          isLoading: _isRepairing,
          onTap: _repairImages,
        ),
        Divider(
            height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
        _buildActionTile(
          icon: Icons.cleaning_services_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Nettoyer les orphelines',
          subtitle: 'Supprimer les images non utilisees',
          isLoading: _isCleaning,
          onTap: _cleanupOrphanImages,
        ),
      ],
    );
  }

  // Cloud content
  Widget _buildCloudContent(bool isDark) {
    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.skyBlue.withOpacity(0.1),
            child: Text(
              _getInitial(AuthService.instance.userName),
              style: TextStyle(
                  color: AppTheme.skyBlue, fontWeight: FontWeight.w600),
            ),
          ),
          title: Text(
            AuthService.instance.userName ?? 'Utilisateur',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            AuthService.instance.userEmail ?? '',
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        Divider(
            height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
        _buildActionTile(
          icon: Icons.sync_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Synchroniser',
          subtitle: 'Mettre a jour manuellement',
          isLoading: _isSyncing,
          onTap: _manualSync,
        ),
        Divider(
            height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
        _buildActionTile(
          icon: Icons.logout_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Deconnexion',
          subtitle: 'Se deconnecter du compte',
          onTap: _handleSignOut,
        ),
      ],
    );
  }

  // Backup content
  Widget _buildBackupContent(bool isDark) {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.upload_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Exporter les notes',
          subtitle: 'Sauvegarde complete avec images',
          isLoading: _isExporting,
          onTap: _exportNotes,
        ),
        Divider(
            height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
        _buildActionTile(
          icon: Icons.download_rounded,
          iconColor: AppTheme.skyBlue,
          title: 'Importer des notes',
          subtitle: 'Restaurer depuis une sauvegarde',
          isLoading: _isImporting,
          onTap: _importNotes,
        ),
      ],
    );
  }

  // Accent color picker
  Widget _buildAccentColorPicker(bool isDark) {
    final currentColor = AccentColorService.instance.accentColor;
    final colors = AccentColorService.availableColors;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.color_lens_rounded,
                  size: 22, color: isDark ? Colors.white70 : AppTheme.textDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Couleur de l\'application',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choisissez votre couleur favorite',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors.map((option) {
              final isSelected = option.color.value == currentColor.value;
              return GestureDetector(
                onTap: () async {
                  await AccentColorService.instance
                      .setAccentColor(option.color);
                  setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? Colors.white : AppTheme.textDark)
                          : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: option.color.withOpacity(0.5),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 24)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Afficher le nom de la couleur selectionnee
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: currentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: currentColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  colors
                      .firstWhere(
                        (c) => c.color.value == currentColor.value,
                        orElse: () =>
                            AccentColorOption('Personnalise', currentColor),
                      )
                      .name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: currentColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Stats tile
  Widget _buildStatsTile(bool isDark) {
    return FutureBuilder<String>(
      future: _getStats(),
      builder: (context, snapshot) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : AppTheme.skyBlue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_rounded,
                    size: 20,
                    color: isDark ? Colors.white70 : AppTheme.skyBlue),
                const SizedBox(width: 12),
                Text(
                  snapshot.data ?? 'Chargement...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : AppTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper pour obtenir l'initiale
  String _getInitial(String? name) {
    if (name == null || name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  // ============= ACTIONS =============

  Future<void> _exportNotes() async {
    setState(() => _isExporting = true);
    try {
      final backupPath = await BackupService.instance.exportToSingleFile();
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showSuccessDialog('Export reussi', 'Fichier sauvegarde:\n$backupPath');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showErrorDialog('Erreur export', e.toString());
    }
  }

  Future<void> _importNotes() async {
    final controller = TextEditingController();
    final filePath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Chemin du fichier .json',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (filePath == null || filePath.isEmpty) return;

    setState(() => _isImporting = true);
    try {
      final count = await BackupService.instance.importFromSingleFile(filePath);
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showSuccessDialog('Import reussi', '$count note(s) importee(s)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      _showErrorDialog('Erreur import', e.toString());
    }
  }

  Future<String> _getStats() async {
    final notes = NoteService.instance.getAllNotes();
    int totalImages = 0;
    for (var note in notes) {
      totalImages += note.imagePaths.length;
    }
    return '${notes.length} notes  •  $totalImages images';
  }

  Future<void> _repairImages() async {
    setState(() => _isRepairing = true);
    try {
      final report = await ImageMigrationService.instance.repairAllImages();
      if (!mounted) return;
      setState(() => _isRepairing = false);
      _showSuccessDialog(
        report.success ? 'Reparation terminee' : 'Erreur',
        report.getSummary(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRepairing = false);
      _showErrorDialog('Erreur', e.toString());
    }
  }

  Future<void> _cleanupOrphanImages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer'),
        content: const Text(
            'Supprimer les images non utilisees? Cette action est irreversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.skyBlue),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCleaning = true);
    try {
      final count = await ImageMigrationService.instance.cleanupOrphanImages();
      if (!mounted) return;
      setState(() => _isCleaning = false);
      _showSuccessDialog('Nettoyage termine', '$count image(s) supprimee(s)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCleaning = false);
      _showErrorDialog('Erreur', e.toString());
    }
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);
    try {
      final report = await CloudSyncService.instance.syncAll();
      if (!mounted) return;
      setState(() => _isSyncing = false);
      _showSuccessDialog(
        report.success ? 'Synchronisation reussie' : 'Erreur',
        report.getSummary(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSyncing = false);
      _showErrorDialog('Erreur sync', e.toString());
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconnexion'),
        content: const Text('Vos notes locales seront conservees.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.skyBlue),
            child: const Text('Deconnexion'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/auth');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur: $e'), backgroundColor: AppTheme.skyBlue),
      );
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isSendingNotif = true);
    try {
      final success =
          await MemoryNotificationService.instance.sendTestNotification();
      if (!mounted) return;
      setState(() => _isSendingNotif = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification envoyee'),
            backgroundColor: AppTheme.skyBlue,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        _showErrorDialog('Notifications',
            'Verifiez les permissions dans les parametres systeme.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingNotif = false);
      _showErrorDialog('Erreur', e.toString());
    }
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.skyBlue, size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_rounded, color: AppTheme.skyBlue, size: 24),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}
