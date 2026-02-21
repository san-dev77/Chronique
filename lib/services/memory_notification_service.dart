import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:math';
import '../models/note.dart';
import 'note_service.dart';

/// Clé de navigation globale pour la redirection depuis les notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MemoryNotificationService {
  static final MemoryNotificationService instance =
      MemoryNotificationService._();
  MemoryNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _isAvailable = true;

  // Préférences pour les notifications
  bool _notifyOnCreate = true;
  bool _memoriesEnabled = true;
  int _memoriesHour = 10; // Heure par défaut : 10h
  int _memoriesMinute = 0;

  // Callback pour ouvrir une note spécifique
  void Function(String noteId)? onOpenNote;

  // Channel IDs pour Android
  static const String _channelId = 'chronique_box_memories';
  static const String _channelName = 'Souvenirs Chroniques';
  static const String _channelDesc =
      'Notifications pour redécouvrir vos anciennes chroniques';

  static const String _channelIdCreate = 'chronique_box_create';
  static const String _channelNameCreate = 'Creation de chroniques';
  static const String _channelDescCreate =
      'Notifications lors de la creation de chroniques';

  // Périodes de souvenirs (en jours)
  static const Map<int, String> memoryPeriods = {
    14: 'Il y a deux semaines...',
    30: 'Il y a un mois...',
    90: 'Il y a trois mois...',
    180: 'Il y a six mois...',
    365: 'Il y a un an...',
    730: 'Il y a deux ans...',
    1095: 'Il y a trois ans...',
  };

  static const List<String> _memoryMessages = [
    'Vous vous souvenez de cette note ?',
    'Un souvenir d\'il y a quelque temps...',
    'Redécouvrez cette chronique',
    'Ce jour-là, vous avez écrit...',
    'Un petit flashback pour vous',
    'Regardez ce que vous aviez noté',
    'Souvenirs, souvenirs...',
    'Une note du passé vous attend',
    'Une pépite de votre collection...',
    'Il s\'est passé quelque chose ce jour-là',
    'Un moment précieux à redécouvrir',
    'Votre carnet a de la mémoire !',
    'Cette chronique vous rappelle quelque chose ?',
    'Retour dans le temps...',
    'Une page de votre histoire',
    'Nostalgie du moment',
    'Votre plume d\'autrefois',
    'Ce passage mérite d\'être relu',
  ];

  // Getters pour les préférences
  bool get notifyOnCreate => _notifyOnCreate;
  bool get memoriesEnabled => _memoriesEnabled;
  int get memoriesHour => _memoriesHour;
  int get memoriesMinute => _memoriesMinute;
  String get memoriesTimeFormatted =>
      '${_memoriesHour.toString().padLeft(2, '0')}:${_memoriesMinute.toString().padLeft(2, '0')}';

  /// Initialise le service de notifications
  Future<void> init() async {
    if (_isInitialized || !_isAvailable) return;

    try {
      // Charger les préférences
      await _loadPreferences();

      // Configuration Android avec icône
      const androidSettings =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      // Configuration iOS
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      debugPrint('Notifications initialized: $initialized');

      // Créer les channels Android
      await _createNotificationChannels();

      _isInitialized = true;
      debugPrint('MemoryNotificationService pret');

      // Planifier le prochain souvenir "direct"
      if (_memoriesEnabled) {
        await scheduleNextMemoryNotification();
      }
    } catch (e) {
      _isAvailable = false;
      debugPrint('Notifications non disponibles: $e');
    }
  }

  /// Charge les préférences utilisateur
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _notifyOnCreate = prefs.getBool('notif_on_create') ?? true;
      _memoriesEnabled = prefs.getBool('notif_memories') ?? true;
      _memoriesHour = prefs.getInt('notif_hour') ?? 10;
      _memoriesMinute = prefs.getInt('notif_minute') ?? 0;
    } catch (e) {
      debugPrint('Erreur chargement prefs: $e');
    }
  }

  /// Sauvegarde les préférences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_on_create', _notifyOnCreate);
      await prefs.setBool('notif_memories', _memoriesEnabled);
      await prefs.setInt('notif_hour', _memoriesHour);
      await prefs.setInt('notif_minute', _memoriesMinute);
    } catch (e) {
      debugPrint('Erreur sauvegarde prefs: $e');
    }
  }

  /// Met à jour les préférences
  Future<void> setNotifyOnCreate(bool value) async {
    _notifyOnCreate = value;
    await _savePreferences();
  }

  Future<void> setMemoriesEnabled(bool value) async {
    _memoriesEnabled = value;
    await _savePreferences();
  }

  Future<void> setMemoriesTime(int hour, int minute) async {
    _memoriesHour = hour;
    _memoriesMinute = minute;
    await _savePreferences();
    
    // Reprogrammer immédiatement le timer "direct"
    if (_memoriesEnabled) {
      await scheduleNextMemoryNotification();
    }
  }

  /// Crée les channels de notification sur Android
  Future<void> _createNotificationChannels() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      // Channel pour les souvenirs
      const channelMemories = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await android.createNotificationChannel(channelMemories);

      // Channel pour les créations
      const channelCreate = AndroidNotificationChannel(
        _channelIdCreate,
        _channelNameCreate,
        description: _channelDescCreate,
        importance: Importance.defaultImportance,
        playSound: false,
        enableVibration: false,
        showBadge: true,
      );
      await android.createNotificationChannel(channelCreate);

      debugPrint('Channels Android crees');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('Notification cliquee: ${response.payload}');
    debugPrint('Action: ${response.actionId}');

    final noteId = response.payload;
    if (noteId != null && noteId.isNotEmpty && noteId != 'test') {
      // Action "Lire la chronique" ou tap sur la notification elle-même
      if (response.actionId == 'read_note' || response.actionId == null || response.actionId!.isEmpty) {
        if (onOpenNote != null) {
          onOpenNote!(noteId);
        } else {
          navigatorKey.currentState?.pushNamed('/note', arguments: noteId);
        }
      }
    }
  }

  /// Demande les permissions de notifications
  Future<bool> requestPermission() async {
    if (!_isAvailable) return false;

    try {
      await init();
      if (!_isInitialized) return false;

      // Android 13+ (API 33) - demander explicitement la permission
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        debugPrint('🔔 Permission Android: $granted');
        if (granted != true) {
          debugPrint('❌ Permission Android refusée');
          return false;
        }
      }

      // iOS - demander explicitement
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🔔 Permission iOS: $granted');
        return granted ?? false;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ Erreur permission: $e');
      return false;
    }
  }

  /// Envoie une notification lors de la création d'une note
  Future<void> sendNoteCreatedNotification(Note note) async {
    if (!_isAvailable || !_notifyOnCreate) return;

    try {
      await init();
      if (!_isInitialized) return;

      final title = note.title.isNotEmpty ? note.title : 'Nouvelle note';

      const androidDetails = AndroidNotificationDetails(
        _channelIdCreate,
        _channelNameCreate,
        channelDescription: _channelDescCreate,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
        enableVibration: false,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        note.id.hashCode + 1000000, // ID unique
        'Vous avez cree aujourd\'hui',
        title,
        details,
        payload: note.id,
      );
    } catch (e) {
      debugPrint('Erreur notification creation: $e');
    }
  }

  /// Envoie une notification de test simple
  Future<bool> sendTestNotification() async {
    try {
      await init();
      if (!_isInitialized) {
        debugPrint('❌ Service non initialisé');
        return false;
      }

      // Demander permission OBLIGATOIREMENT
      final hasPermission = await requestPermission();
      debugPrint('🔔 Permission obtenue pour test: $hasPermission');
      if (!hasPermission) {
        debugPrint(
            '❌ Permission refusée - impossible d\'envoyer la notification');
        return false;
      }

      // Notification simple de test avec logo et action
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        ticker: 'Chroniques',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'view_memory',
            'Voir le moment',
            showsUserInterface: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _notifications.show(
        id,
        'Chroniques - Test',
        'Les notifications fonctionnent correctement !',
        details,
        payload: 'test',
      );

      debugPrint('✅ Notification test envoyée (id: $id)');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur notification test: $e');
      return false;
    }
  }

  /// Planifie une notification de souvenir
  Future<void> scheduleDailyMemoryNotification() async {
    if (!_isAvailable) return;

    try {
      await init();
      if (!_isInitialized) return;

      final notes = await NoteService.instance.getAllNotes();
      if (notes.isEmpty) {
        debugPrint('⚠️ Pas de notes pour la notification');
        return;
      }

      final random = Random();
      final randomNote = notes[random.nextInt(notes.length)];
      final randomMessage =
          _memoryMessages[random.nextInt(_memoryMessages.length)];

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        styleInformation: BigTextStyleInformation(''),
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'view_memory',
            'Voir le moment',
            showsUserInterface: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final noteContent = randomNote.title.isNotEmpty
          ? randomNote.title
          : (randomNote.content.length > 50
              ? '${randomNote.content.substring(0, 50)}...'
              : randomNote.content);

      await _notifications.show(
        0,
        randomMessage,
        noteContent,
        details,
        payload: randomNote.id,
      );

      debugPrint('Notification souvenir envoyee: $randomMessage');
    } catch (e) {
      debugPrint('❌ Erreur notification souvenir: $e');
      rethrow; // Pour que l'appelant sache qu'il y a eu une erreur
    }
  }

  /// Planification précise via Workmanager
  Future<void> scheduleNextMemoryNotification() async {
    try {
      final now = DateTime.now();
      var scheduledDate = DateTime(
        now.year,
        now.month,
        now.day,
        _memoriesHour,
        _memoriesMinute,
      );

      // Si l'heure est déjà passée aujourd'hui, on planifie pour demain
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final delay = scheduledDate.difference(now);
      
      debugPrint('🚀 Scheduling memory task in $delay (${scheduledDate})');

      await Workmanager().registerOneOffTask(
        'notebox_memories_oneoff_task',
        'notebox_memories_oneoff_task',
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace, // Très important pour ne pas empiler
        constraints: Constraints(
          networkType: NetworkType.not_required,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('next_scheduled_notif', scheduledDate.toIso8601String());

    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Affiche une notification locale avec bouton d'action
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isAvailable) return;

    try {
      await init();
      if (!_isInitialized) return;

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'read_note',
            'Lire la chronique',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Erreur showLocalNotification: $e');
    }
  }

  /// Envoie une notification de souvenir immédiate
  Future<void> sendMemoryNotification(Note note,
      {String? customMessage}) async {
    final random = Random();
    final message = customMessage ??
        _memoryMessages[random.nextInt(_memoryMessages.length)];

    await showLocalNotification(
      id: note.id.hashCode,
      title: message,
      body: note.title.isNotEmpty
          ? note.title
          : (note.content.length > 50
              ? '${note.content.substring(0, 50)}...'
              : note.content),
      payload: note.id,
    );
  }

  /// Envoie une notification de note aléatoire (demandé par l'utilisateur)
  Future<void> sendRandomNoteNotification() async {
    if (!_isAvailable) return;

    try {
      await init();
      if (!_isInitialized) return;

      final notes = await NoteService.instance.getAllNotes();
      if (notes.isEmpty) return;

      final random = Random();
      final note = notes[random.nextInt(notes.length)];

      await sendMemoryNotification(note,
          customMessage: 'Redécouvrez une note au hasard');
      debugPrint('Notification note aléatoire envoyée');
    } catch (e) {
      debugPrint('Erreur notification aléatoire: $e');
    }
  }

  /// Vérifie si c'est l'heure d'envoyer la notification
  Future<void> checkAndNotifyMemories({bool force = false}) async {
    if (!_isAvailable || !_memoriesEnabled) return;

    try {
      final now = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      final lastNotifKey = 'last_notif_date';
      final today = '${now.year}-${now.month}-${now.day}';

      if (!force) {
        // Heure configurée convertie en minutes depuis minuit
        final configMinutes = _memoriesHour * 60 + _memoriesMinute;
        final currentMinutes = now.hour * 60 + now.minute;

        if (currentMinutes < configMinutes) {
          debugPrint(
              'Trop tôt pour les souvenirs ($currentMinutes < $configMinutes)');
          await prefs.setString('last_notif_reason',
              'En attente de ${memoriesTimeFormatted}');
          return;
        }

        // Fenêtre de tir : on n'envoie que si on est dans l'heure qui suit l'heure prévue
        if (currentMinutes > configMinutes + 60) {
          debugPrint('Heure passée pour aujourd\'hui ($currentMinutes > ${configMinutes + 60})');
          await prefs.setString('last_notif_reason', 'Heure dépassée pour aujourd\'hui');
          return;
        }

        // Vérifier si on a déjà notifié aujourd'hui
        if (prefs.getString(lastNotifKey) == today) {
          debugPrint('Déjà notifié aujourd\'hui ($today)');
          await prefs.setString(
              'last_notif_reason', 'Déjà notifié aujourd\'hui');
          return;
        }
      }

      final notes = await NoteService.instance.getAllNotes();
      if (notes.isEmpty) {
        await prefs.setString('last_notif_reason', 'Aucune note disponible');
        return;
      }

      // === Anti-doublon : charger les IDs envoyés récemment ===
      final sentIdsRaw = prefs.getStringList('sent_note_ids') ?? [];
      final sentDatesRaw = prefs.getStringList('sent_note_dates') ?? [];
      final cutoff = now.subtract(const Duration(days: 7));
      
      // Nettoyer les entrées > 7 jours
      final cleanIds = <String>[];
      final cleanDates = <String>[];
      for (int i = 0; i < sentIdsRaw.length && i < sentDatesRaw.length; i++) {
        final date = DateTime.tryParse(sentDatesRaw[i]);
        if (date != null && date.isAfter(cutoff)) {
          cleanIds.add(sentIdsRaw[i]);
          cleanDates.add(sentDatesRaw[i]);
        }
      }
      final recentlyNotifiedIds = cleanIds.toSet();

      final random = Random();

      // 1. Chercher des souvenirs spécifiques (anniversaires, etc)
      for (final entry in memoryPeriods.entries) {
        final days = entry.key;
        final message = entry.value;
        final tolerance = days < 60 ? 1 : 3;

        final periodNotes = notes.where((note) {
          final diff = now.difference(note.createdAt).inDays;
          return diff >= days - tolerance && diff <= days + tolerance &&
              !recentlyNotifiedIds.contains(note.id);
        }).toList();

        if (periodNotes.isNotEmpty) {
          final note = periodNotes[random.nextInt(periodNotes.length)];
          await sendMemoryNotification(note, customMessage: message);
          await prefs.setString(lastNotifKey, today);
          // Enregistrer cet ID comme envoyé
          cleanIds.add(note.id);
          cleanDates.add(now.toIso8601String());
          await prefs.setStringList('sent_note_ids', cleanIds);
          await prefs.setStringList('sent_note_dates', cleanDates);
          return;
        }
      }

      // 2. Sinon, envoyer une note aléatoire (pas récemment notifiée)
      final available = notes.where((n) => !recentlyNotifiedIds.contains(n.id)).toList();
      final pool = available.isNotEmpty ? available : notes;
      final note = pool[random.nextInt(pool.length)];
      await sendMemoryNotification(note,
          customMessage: _memoryMessages[random.nextInt(_memoryMessages.length)]);
      await prefs.setString(lastNotifKey, today);
      // Enregistrer cet ID comme envoyé
      cleanIds.add(note.id);
      cleanDates.add(now.toIso8601String());
      await prefs.setStringList('sent_note_ids', cleanIds);
      await prefs.setStringList('sent_note_dates', cleanDates);
      await prefs.setString(
          'last_notif_reason', 'Souvenir envoyé (${now.hour}:${now.minute})');
    } catch (e) {
      debugPrint('Erreur checkAndNotifyMemories: $e');
    }
  }

  /// Retourne les prochaines notifications prévues
  List<Map<String, dynamic>> getUpcomingMemories() {
    final notes = NoteService.instance.getAllNotes();
    final now = DateTime.now();
    final upcoming = <Map<String, dynamic>>[];

    for (final entry in memoryPeriods.entries) {
      final days = entry.key;
      final message = entry.value;

      // Chercher les notes qui vont bientôt atteindre cette période
      for (final note in notes) {
        final noteAge = now.difference(note.createdAt).inDays;
        final daysUntil = days - noteAge;

        if (daysUntil > 0 && daysUntil <= 7) {
          upcoming.add({
            'note': note,
            'message': message,
            'daysUntil': daysUntil,
            'period': days,
          });
        }
      }
    }

    // Trier par date la plus proche
    upcoming.sort(
        (a, b) => (a['daysUntil'] as int).compareTo(b['daysUntil'] as int));
    return upcoming.take(10).toList(); // Max 10
  }

  /// Retourne les statistiques de souvenirs disponibles
  Map<String, int> getMemoryStats() {
    final notes = NoteService.instance.getAllNotes();
    final now = DateTime.now();
    final stats = <String, int>{};

    for (final entry in memoryPeriods.entries) {
      final days = entry.key;
      final message = entry.value;
      final tolerance = days < 60 ? 2 : 5;

      final count = notes.where((note) {
        final diff = now.difference(note.createdAt).inDays;
        return diff >= days - tolerance && diff <= days + tolerance;
      }).length;

      if (count > 0) {
        stats[message] = count;
      }
    }

    return stats;
  }
}
