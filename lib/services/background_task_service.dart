import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../firebase_options.dart';
import '../models/app_notification.dart';
import 'memory_notification_service.dart';

/// Nom de la tâche de fond pour les souvenirs
const String memoriesTaskName = 'notebox_memories_task';
const String memoriesTaskTag = 'memories';

/// Callback exécuté en arrière-plan
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BackgroundTask: $task');
    
    try {
      if (task == memoriesTaskName || task == Workmanager.iOSBackgroundTask) {
        // Enregistrer le dernier run
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_background_run', DateTime.now().toIso8601String());
        
        // Initialiser Firebase (nécessaire pour Firestore en arrière-plan)
        // Note: Firebase.initializeApp() doit être appelé ici si ce n'est pas déjà fait 
        // par d'autres services, mais généralement Workmanager l'exige.
        
        // Vérifier et envoyer les notifications de souvenirs
        await MemoryNotificationService.instance.init();
        await MemoryNotificationService.instance.checkAndNotifyMemories();
        
        // --- NOUVEAU : Vérifier les notifications de partage/reactions ---
        // On récupère manuellement car le listener Stream ne tourne pas en tâche de fond fixe
        final user = await _getBackgroundUser();
        if (user != null) {
          await _checkUnreadNotifications(user.uid);
        }
        
        debugPrint('BackgroundTask: Souvenirs et Notifications verifies');
      }
      return true;
    } catch (e) {
      debugPrint('BackgroundTask error: $e');
      return false;
    }
  });
}

/// Helper pour récupérer l'utilisateur en tâche de fond
Future<User?> _getBackgroundUser() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    return FirebaseAuth.instance.currentUser;
  } catch (e) {
    return null;
  }
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
      
      // Afficher la notification locale
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
  bool _isRunning = false;

  bool get isInitialized => _isInitialized;
  bool get isRunning => _isRunning;

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

  /// Démarre la tâche périodique de souvenirs
  Future<void> startMemoriesTask() async {
    if (!_isInitialized) await init();

    try {
      // Annuler les tâches existantes
      await Workmanager().cancelByTag(memoriesTaskTag);

      // Programmer une tâche périodique (minimum 15 min sur Android)
      await Workmanager().registerPeriodicTask(
        memoriesTaskName,
        memoriesTaskName,
        tag: memoriesTaskTag,
        frequency: const Duration(hours: 12), // 2 fois par jour
        constraints: Constraints(
          networkType: NetworkType.not_required,
          requiresBatteryNotLow: true,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 15),
      );

      _isRunning = true;
      
      // Sauvegarder l'état
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_task_enabled', true);
      await prefs.setString('background_task_started', DateTime.now().toIso8601String());

      debugPrint('Tache de fond demarree');
    } catch (e) {
      debugPrint('Erreur demarrage tache: $e');
    }
  }

  /// Arrête la tâche de souvenirs
  Future<void> stopMemoriesTask() async {
    try {
      await Workmanager().cancelByTag(memoriesTaskTag);
      _isRunning = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('background_task_enabled', false);

      debugPrint('Tache de fond arretee');
    } catch (e) {
      debugPrint('Erreur arret tache: $e');
    }
  }

  /// Vérifie si la tâche est active (active par defaut)
  Future<bool> isTaskEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('background_task_enabled') ?? true;
  }

  /// Récupère la date du dernier run
  Future<DateTime?> getLastRunTime() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRun = prefs.getString('last_background_run');
    if (lastRun != null) {
      return DateTime.tryParse(lastRun);
    }
    return null;
  }

  /// Récupère la date de démarrage de la tâche
  Future<DateTime?> getTaskStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final started = prefs.getString('background_task_started');
    if (started != null) {
      return DateTime.tryParse(started);
    }
    return null;
  }

  /// Formate une durée relative
  String formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Jamais';
    
    final diff = DateTime.now().difference(dateTime);
    
    if (diff.inMinutes < 1) return 'A l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
