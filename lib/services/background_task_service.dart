import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../firebase_options.dart';
import '../models/app_notification.dart';
import 'memory_notification_service.dart';
import 'auth_service.dart';
import 'note_service.dart';

/// Nom de la tâche de fond pour les souvenirs
const String memoriesTaskName = 'notebox_memories_task';
const String memoriesTaskTag = 'memories';

/// Callback exécuté en arrière-plan
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final now = DateTime.now();
    debugPrint('Native: Background task triggered: $task at $now');
    
    try {
      // 1. Déclarer prefs tout de suite
      final prefs = await SharedPreferences.getInstance();

      // 2. Initialiser le stockage (Indispensable pour NoteService)
      await Hive.initFlutter();
      
      // 3. Initialiser Firebase
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      
      final auth = FirebaseAuth.instance;
      String? userId = auth.currentUser?.uid;
      
      // FALLBACK: Si FirebaseAuth n'est pas synchro dans l'isolate, utiliser SharedPreferences
      if (userId == null) {
        userId = prefs.getString('current_user_id');
        debugPrint('Worker: Fallback to stored userId: $userId');
      } else {
        debugPrint('Worker: Firebase current user: $userId');
      }

      if (task == memoriesTaskName || task == Workmanager.iOSBackgroundTask) {
        // --- 1. POLLING STORIES (Fréquent : toutes les 15 min) ---
        // On vérifie toujours les notifications sociales si un utilisateur est connecté
        if (userId != null) {
          debugPrint('Worker: Checking stories for $userId');
          await _checkUnreadNotifications(userId);
        }

        // --- 2. SOUVENIRS (Quotidien : 1x/jour à l'heure choisie) ---
        // Le service MemoryNotificationService gère lui-même le verrou de 24h et l'heure
        await NoteService.instance.initializeForUser(userId);
        await MemoryNotificationService.instance.init();
        await MemoryNotificationService.instance.checkAndNotifyMemories();
        
        // Mettre à jour les logs système
        await prefs.setString('last_worker_run', now.toIso8601String());
        await prefs.setString('last_background_run', now.toIso8601String());
        debugPrint('Worker: Cycle complete at $now');
      }
      return true;
    } catch (e) {
      debugPrint('Worker error: $e');
      return false;
    }
  });
}

/// Helper pour vérifier les notifications non lues en tâche de fond
Future<void> _checkUnreadNotifications(String userId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in snapshot.docs) {
      final notif = AppNotification.fromFirestore(doc);
      
      await MemoryNotificationService.instance.showLocalNotification(
        id: notif.id.hashCode,
        title: notif.title,
        body: notif.body,
        payload: notif.sharedNoteId ?? notif.noteId,
      );

      // Marquer comme lue
      await doc.reference.update({'isRead': true});
    }
  } catch (e) {
    debugPrint('Error checking background notifications: $e');
  }
}

class BackgroundTaskService {
  static final BackgroundTaskService instance = BackgroundTaskService._();
  BackgroundTaskService._();

  bool _isInitialized = false;

  /// Initialise le service de tâches de fond
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: false,
      );
      _isInitialized = true;
      debugPrint('BackgroundTaskService initialise');
    } catch (e) {
      debugPrint('BackgroundTaskService erreur: $e');
    }
  }

  /// Démarre ou redémarre la tâche périodique
  Future<void> startMemoriesTask() async {
    if (!_isInitialized) await init();

    try {
      // On enregistre la tâche de manière persistante.
      // IMPORTANT: On utilise ExistingWorkPolicy.keep pour ne PAS réinitialiser le timer à chaque démarrage de l'app.
      await Workmanager().registerPeriodicTask(
        memoriesTaskName,
        memoriesTaskName,
        tag: memoriesTaskTag,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.keep,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_task_enabled', true);
      await prefs.setString('background_task_started', DateTime.now().toIso8601String());
      // Re-trigger a last run date to ensure UI doesn't show "Never" if it just started
      await prefs.setString('last_worker_run', DateTime.now().toIso8601String());

      debugPrint('Tache de fond demarree (freq: 15 min)');
    } catch (e) {
      debugPrint('Erreur demarrage tache: $e');
    }
  }

  Future<void> stopMemoriesTask() async {
    try {
      await Workmanager().cancelByTag(memoriesTaskTag);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_task_enabled', false);
      debugPrint('Tache de fond arretee');
    } catch (e) {
      debugPrint('Erreur arret tache: $e');
    }
  }

  Future<bool> isTaskEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('background_task_enabled') ?? true;
  }

  Future<DateTime?> getLastRunTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRun = prefs.getString('last_background_run');
    return lastRun != null ? DateTime.tryParse(lastRun) : null;
  }

  /// Simule une exécution du worker (utile pour le debug)
  Future<void> debugForceRun() async {
    // 1. Priorité à l'utilisateur actuellement connecté via AuthService (plus fiable en foreground)
    String? userId = AuthService.instance.userId;
    
    // 2. Fallback sur SharedPreferences (contexte background pur)
    if (userId == null) {
      final prefs = await SharedPreferences.getInstance();
      userId = prefs.getString('current_user_id');
    }
    
    print('Force Run: Simulating worker for user $userId');
    
    // 3. Initialiser les services
    await NoteService.instance.initializeForUser(userId);
    await MemoryNotificationService.instance.init();
    
    final notes = NoteService.instance.getAllNotes();
    print('Force Run: Found ${notes.length} notes in current box');
    
    // 4. Forcer le check des souvenirs (Bypass du verrou journalier pour le debug)
    await MemoryNotificationService.instance.checkAndNotifyMemories(force: true);
    
    // 5. Check social notifications (Toujours déverrouillé par défaut)
    if (userId != null) {
      await _checkUnreadNotifications(userId);
    }
    
    // Mettre à jour la date du dernier run (simulation)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_background_run', DateTime.now().toIso8601String());
  }

  String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Jamais';
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'A l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
