import 'package:flutter/material.dart';
import '../widgets/app_launcher_preview.dart';
import '../services/backup_service.dart';
import '../services/note_service.dart';
import '../services/image_migration_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Paramètres',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section Apparence
                _buildSectionCard(
                  title: '🎨 Apparence',
                  subtitle: 'Personnaliser l\'interface',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.brightness_6),
                      title: const Text('Thème sombre'),
                      subtitle: const Text('Basculer entre clair et sombre'),
                      trailing: Switch(
                        value: Theme.of(context).brightness == Brightness.dark,
                        onChanged: (value) {
                          // TODO: Implémenter le changement de thème
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section Images (NOUVEAU - PRIORITÉ)
                _buildSectionCard(
                  title: '🖼️ Gestion des Images',
                  subtitle: 'Réparer et optimiser',
                  children: [
                    FutureBuilder<ImageAnalysisReport>(
                      future: ImageMigrationService.instance.analyzeImages(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          final report = snapshot.data!;
                          return Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: report.hasIssues()
                                      ? Colors.orange.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  report.getSummary(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: report.hasIssues()
                                        ? Colors.orange.shade900
                                        : Colors.green.shade900,
                                  ),
                                ),
                              ),
                              if (report.hasIssues()) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed:
                                        _isRepairing ? null : _repairImages,
                                    icon: _isRepairing
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.build),
                                    label: Text(_isRepairing
                                        ? 'Réparation...'
                                        : 'Réparer les images'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services,
                          color: Colors.purple),
                      title: const Text('Nettoyer images orphelines'),
                      subtitle: const Text('Supprime les images non utilisées'),
                      trailing: _isCleaning
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _isCleaning ? null : _cleanupOrphanImages,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section Sync Cloud (si connecté)
                if (AuthService.instance.isSignedIn) ...[
                  _buildSectionCard(
                    title: '☁️ Synchronisation Cloud',
                    subtitle: 'Vos notes sur tous vos appareils',
                    children: [
                      ListTile(
                        leading: const Icon(Icons.account_circle,
                            color: Colors.blue),
                        title: Text(
                            AuthService.instance.userName ?? 'Utilisateur'),
                        subtitle: Text(AuthService.instance.userEmail ?? ''),
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.sync, color: Colors.green),
                        title: const Text('Synchroniser maintenant'),
                        subtitle: const Text('Sync manuelle des notes'),
                        trailing: _isSyncing
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: _isSyncing ? null : _manualSync,
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Déconnexion'),
                        subtitle: const Text('Se déconnecter du compte'),
                        onTap: _handleSignOut,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Section Sauvegarde & Données
                _buildSectionCard(
                  title: '💾 Sauvegarde & Données',
                  subtitle: 'Protégez vos notes',
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.upload_file, color: Colors.blue),
                      title: const Text('Exporter toutes les notes'),
                      subtitle: const Text('Sauvegarde complète avec images'),
                      trailing: _isExporting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _isExporting ? null : _exportNotes,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.download, color: Colors.green),
                      title: const Text('Importer des notes'),
                      subtitle: const Text('Restaurer depuis une sauvegarde'),
                      trailing: _isImporting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _isImporting ? null : _importNotes,
                    ),
                    const Divider(),
                    ListTile(
                      leading:
                          const Icon(Icons.info_outline, color: Colors.orange),
                      title: const Text('Statistiques'),
                      subtitle: FutureBuilder<String>(
                        future: _getStats(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return Text(snapshot.data!);
                          }
                          return const Text('Calcul en cours...');
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section À propos
                _buildSectionCard(
                  title: 'ℹ️ À propos',
                  subtitle: 'Informations sur l\'application',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('Version'),
                      subtitle: const Text('Note Box v1.0.0'),
                    ),
                    const AppLauncherPreview(),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _exportNotes() async {
    setState(() => _isExporting = true);

    try {
      final backupPath = await BackupService.instance.exportToSingleFile();

      if (!mounted) return;

      setState(() => _isExporting = false);

      // Afficher le chemin de sauvegarde
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Export réussi !'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vos notes ont été sauvegardées avec succès.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('📁 Emplacement :'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  backupPath,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '💡 Conseil : Copiez ce fichier sur un autre appareil ou dans le cloud pour plus de sécurité.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isExporting = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Erreur'),
            ],
          ),
          content: Text('Impossible d\'exporter les notes :\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importNotes() async {
    // Afficher dialogue de sélection
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importer des notes'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📂 Instructions :',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
                '1. Localisez votre fichier de sauvegarde (NoteBox_Export_*.json)'),
            SizedBox(height: 8),
            Text(
                '2. Entrez le chemin complet du fichier dans la fenêtre suivante'),
            SizedBox(height: 16),
            Text(
              '⚠️ Les notes importées seront ajoutées aux notes existantes (pas de suppression).',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Demander le chemin du fichier
    final controller = TextEditingController();
    final filePath = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chemin du fichier'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '/chemin/vers/NoteBox_Export_xxx.json',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
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

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Import réussi !'),
            ],
          ),
          content: Text(
            '$count note(s) ont été importées avec succès.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Retourner à l'écran principal pour voir les notes
                Navigator.pop(context);
              },
              child: const Text('Voir les notes'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isImporting = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Erreur'),
            ],
          ),
          content: Text('Impossible d\'importer les notes :\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<String> _getStats() async {
    try {
      final notes = NoteService.instance.getAllNotes();
      final totalNotes = notes.length;

      int totalImages = 0;
      for (var note in notes) {
        totalImages += note.imagePaths.length;
      }

      return '$totalNotes note(s) • $totalImages image(s)';
    } catch (e) {
      return 'Erreur de calcul';
    }
  }

  Future<void> _repairImages() async {
    setState(() => _isRepairing = true);

    try {
      final report = await ImageMigrationService.instance.repairAllImages();

      if (!mounted) return;

      setState(() => _isRepairing = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                report.success ? Icons.check_circle : Icons.error,
                color: report.success ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(report.success ? 'Réparation terminée' : 'Erreur'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(report.getSummary()),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Rafraîchir l'écran pour voir les changements
                setState(() {});
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isRepairing = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Erreur'),
            ],
          ),
          content: Text('Impossible de réparer les images :\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _cleanupOrphanImages() async {
    // Confirmer d'abord
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer les images ?'),
        content: const Text(
          'Cette action supprimera toutes les images qui ne sont plus '
          'associées à une note.\n\nCette opération est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Nettoyer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCleaning = true);

    try {
      final deletedCount =
          await ImageMigrationService.instance.cleanupOrphanImages();

      if (!mounted) return;

      setState(() => _isCleaning = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Nettoyage terminé'),
            ],
          ),
          content: Text(
            '$deletedCount image(s) orpheline(s) supprimée(s).',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {}); // Rafraîchir
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isCleaning = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Erreur'),
            ],
          ),
          content: Text('Impossible de nettoyer :\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    setState(() => _isSyncing = true);

    try {
      final report = await CloudSyncService.instance.syncAll();

      if (!mounted) return;

      setState(() => _isSyncing = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                report.success ? Icons.check_circle : Icons.error,
                color: report.success ? Colors.green : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(report.success ? 'Sync réussie' : 'Erreur'),
            ],
          ),
          content: Text(report.getSummary()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSyncing = false);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.red, size: 28),
              SizedBox(width: 12),
              Text('Erreur'),
            ],
          ),
          content: Text('Impossible de synchroniser :\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text(
          'Êtes-vous sûr de vouloir vous déconnecter ?\n\n'
          'Vos notes locales seront conservées mais ne seront plus synchronisées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Déconnexion'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AuthService.instance.signOut();

      if (!mounted) return;

      // Retourner à l'écran d'authentification
      Navigator.pushReplacementNamed(context, '/auth');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur de déconnexion: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
