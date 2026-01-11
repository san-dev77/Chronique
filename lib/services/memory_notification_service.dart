import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  static const String _channelId = 'note_box_memories';
  static const String _channelName = 'Souvenirs Note Box';
  static const String _channelDesc = 'Notifications pour redécouvrir vos anciennes notes';
  
  static const String _channelIdCreate = 'note_box_create';
  static const String _channelNameCreate = 'Creation de notes';
  static const String _channelDescCreate = 'Notifications lors de la creation de notes';

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
    'Redécouvrez cette note',
    'Ce jour-là, vous avez écrit...',
    'Un petit flashback pour vous',
    'Regardez ce que vous aviez noté',
    'Souvenirs, souvenirs...',
    'Une note du passé vous attend',
  ];
  
  // Getters pour les préférences
  bool get notifyOnCreate => _notifyOnCreate;
  bool get memoriesEnabled => _memoriesEnabled;
  int get memoriesHour => _memoriesHour;
  int get memoriesMinute => _memoriesMinute;
  String get memoriesTimeFormatted => '${_memoriesHour.toString().padLeft(2, '0')}:${_memoriesMinute.toString().padLeft(2, '0')}';

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
      // Ouvrir la note spécifique
      if (onOpenNote != null) {
        onOpenNote!(noteId);
      } else {
        // Fallback: naviguer vers la note view
        navigatorKey.currentState?.pushNamed('/note', arguments: noteId);
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
        ticker: 'Note Box',
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
        'Note Box - Test',
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

  /// Envoie une notification de souvenir immédiate
  Future<void> sendMemoryNotification(Note note,
      {String? customMessage}) async {
    if (!_isAvailable) return;

    try {
      await init();
      if (!_isInitialized) return;

      final random = Random();
      final message = customMessage ??
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

      await _notifications.show(
        note.id.hashCode,
        message,
        note.title.isNotEmpty
            ? note.title
            : (note.content.length > 50
                ? '${note.content.substring(0, 50)}...'
                : note.content),
        details,
        payload: note.id,
      );
    } catch (e) {
      debugPrint('Erreur notification: $e');
    }
  }

  /// Vérifie si des souvenirs sont disponibles et envoie une notification
  Future<void> checkAndNotifyMemories() async {
    if (!_isAvailable || !_memoriesEnabled) return;

    try {
      final notes = NoteService.instance.getAllNotes();
      final now = DateTime.now();
      final random = Random();
      
      // Vérifier chaque période de souvenir
      for (final entry in memoryPeriods.entries) {
        final days = entry.key;
        final message = entry.value;
        final tolerance = days < 60 ? 2 : 5; // Tolérance de 2j pour les courtes périodes, 5j sinon
        
        final periodNotes = notes.where((note) {
          final diff = now.difference(note.createdAt).inDays;
          return diff >= days - tolerance && diff <= days + tolerance;
        }).toList();
        
        if (periodNotes.isNotEmpty) {
          // Envoyer une notif pour cette période
          final note = periodNotes[random.nextInt(periodNotes.length)];
          await sendMemoryNotification(note, customMessage: message);
          
          // Si plusieurs notes dans la période, mentionner le nombre
          if (periodNotes.length > 1) {
            debugPrint('${periodNotes.length} notes trouvees pour la periode: $message');
          }
          return; // Une seule notif par check
        }
      }

      // Si aucune période spéciale, envoyer un souvenir aléatoire (notes > 2 semaines)
      final oldNotes = notes
          .where((note) => now.difference(note.createdAt).inDays > 14)
          .toList();
      if (oldNotes.length >= 3) {
        final note = oldNotes[random.nextInt(oldNotes.length)];
        await sendMemoryNotification(note);
      }
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
    upcoming.sort((a, b) => (a['daysUntil'] as int).compareTo(b['daysUntil'] as int));
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
