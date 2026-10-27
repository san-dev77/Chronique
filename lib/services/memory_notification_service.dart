import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:io';
import 'dart:math';
import '../models/note.dart';
import '../utils/app_paths.dart';
import 'memory_periods.dart';
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
  // Le souvenir du soir, a 23 h : l'heure choisie.
  int _memoriesHour = 23;
  int _memoriesMinute = 0;

  /// Seconde notification de la journee : elle mene au diaporama d'une
  /// periode (« il y a trois mois »). Posee le matin pour ne pas tomber en
  /// meme temps que celle du soir.
  bool _slideshowEnabled = true;
  int _slideshowHour = 8;
  int _slideshowMinute = 0;

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
  /// Conservee pour les ecrans qui l'affichent encore.
  static Map<int, String> get memoryPeriods =>
      {for (final p in MemoryPeriod.all) p.days: p.label};

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
  bool get slideshowEnabled => _slideshowEnabled;
  int get slideshowHour => _slideshowHour;
  int get slideshowMinute => _slideshowMinute;
  String get slideshowTimeFormatted =>
      '${_slideshowHour.toString().padLeft(2, '0')}:'
      '${_slideshowMinute.toString().padLeft(2, '0')}';
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

      // Demander l'autorisation de notifier, une fois.
      //
      // Elle n'etait reclamee que par le bouton « Tester les notifications »
      // des reglages. Sur Android 13 et au-dela, une installation neuve
      // n'affichait donc jamais la moindre notification tant que personne
      // n'avait trouve ce bouton.
      await _requestPermissionOnce();

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
      _memoriesHour = prefs.getInt('notif_hour') ?? 23;
      _memoriesMinute = prefs.getInt('notif_minute') ?? 0;
      _slideshowEnabled = prefs.getBool('notif_slideshow') ?? true;
      _slideshowHour = prefs.getInt('notif_slideshow_hour') ?? 8;
      _slideshowMinute = prefs.getInt('notif_slideshow_minute') ?? 0;
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
      await prefs.setBool('notif_slideshow', _slideshowEnabled);
      await prefs.setInt('notif_slideshow_hour', _slideshowHour);
      await prefs.setInt('notif_slideshow_minute', _slideshowMinute);
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

  Future<void> setSlideshowEnabled(bool value) async {
    _slideshowEnabled = value;
    await _savePreferences();
  }

  Future<void> setSlideshowTime(int hour, int minute) async {
    _slideshowHour = hour;
    _slideshowMinute = minute;
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
  /// Demande l'autorisation au premier lancement, puis plus jamais.
  ///
  /// Un refus se respecte : le systeme ne reaffiche pas la demande, et
  /// insister a chaque demarrage ne ferait que gener.
  Future<void> _requestPermissionOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('notif_permission_asked') ?? false) return;
      await prefs.setBool('notif_permission_asked', true);
      final granted = await requestPermission();
      debugPrint('Autorisation de notifier : $granted');
    } catch (e) {
      debugPrint('Demande d autorisation impossible: $e');
    }
  }

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

      // Pas de WorkManager sur desktop : la planification y echouerait a
      // chaque demarrage, pour une erreur qui ne veut rien dire ici.
      if (AppPaths.isDesktop) return;

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
  /// [bigText] deplie la notification sur le texte de la chronique.
  /// [imagePath] y pose une photo, pour la notification du matin.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? bigText,
    String? imagePath,
  }) async {
    if (!_isAvailable) return;

    try {
      await init();
      if (!_isInitialized) return;

      // Une notification repliee ne montre qu'une ligne. Depliee, elle porte
      // soit la photo du souvenir, soit le texte de la chronique — de quoi
      // decider si on a envie de la rouvrir sans quitter l'ecran de veille.
      StyleInformation? style;
      if (imagePath != null && await File(imagePath).exists()) {
        style = BigPictureStyleInformation(
          FilePathAndroidBitmap(imagePath),
          contentTitle: title,
          summaryText: body,
          hideExpandedLargeIcon: true,
        );
      } else if (bigText != null && bigText.trim().isNotEmpty) {
        style = BigTextStyleInformation(
          bigText.trim(),
          contentTitle: title,
          summaryText: body,
        );
      }

      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        styleInformation: style,
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

    final heading = note.title.trim().isNotEmpty
        ? note.title.trim()
        : (note.quote?.trim().isNotEmpty ?? false)
            ? note.quote!.trim()
            : 'Une chronique à relire';

    // Le corps de la chronique accompagne le titre : deplier la notification
    // suffit alors a retrouver le souvenir, sans ouvrir l'application.
    final excerpt = _excerpt(note);

    await showLocalNotification(
      id: note.id.hashCode,
      title: message,
      body: heading,
      payload: note.id,
      bigText: excerpt.isEmpty ? null : '$heading\n\n$excerpt',
    );
  }

  /// Un extrait lisible de la chronique, cite d'abord, texte ensuite.
  String _excerpt(Note note, {int max = 320}) {
    final parts = <String>[];
    final quote = note.quote?.trim() ?? '';
    final content = note.content.trim();
    if (quote.isNotEmpty && quote != note.title.trim()) {
      parts.add('« $quote »');
    }
    if (content.isNotEmpty) parts.add(content);

    var text = parts.join('\n\n');
    if (text.length > max) {
      text = '${text.substring(0, max).trimRight()}…';
    }
    return text;
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

  /// L'heure est-elle venue, et n'a-t-on pas deja envoye aujourd'hui ?
  ///
  /// L'ancienne version refusait d'envoyer passe une heure apres l'horaire
  /// prevu. Android ne reveille pas une tache de fond a la minute demandee :
  /// la fenetre etait ratee la plupart du temps, et le journal se remplissait
  /// de « Heure dépassée pour aujourd'hui ». On envoie desormais au premier
  /// reveil qui suit l'horaire, ce qui est tard de quelques minutes mais
  /// jamais perdu.
  Future<bool> _isDue(
      SharedPreferences prefs, String key, int hour, int minute) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (prefs.getString(key) == today) return false;
    return now.hour * 60 + now.minute >= hour * 60 + minute;
  }

  Future<void> _markSent(SharedPreferences prefs, String key) async {
    final now = DateTime.now();
    await prefs.setString(key, '${now.year}-${now.month}-${now.day}');
  }

  /// Les chroniques deja mises en avant ces sept derniers jours.
  Future<Set<String>> _recentlySent(SharedPreferences prefs) async {
    final ids = prefs.getStringList('sent_note_ids') ?? [];
    final dates = prefs.getStringList('sent_note_dates') ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final keep = <String>{};
    final cleanIds = <String>[];
    final cleanDates = <String>[];
    for (var i = 0; i < ids.length && i < dates.length; i++) {
      final date = DateTime.tryParse(dates[i]);
      if (date != null && date.isAfter(cutoff)) {
        keep.add(ids[i]);
        cleanIds.add(ids[i]);
        cleanDates.add(dates[i]);
      }
    }
    await prefs.setStringList('sent_note_ids', cleanIds);
    await prefs.setStringList('sent_note_dates', cleanDates);
    return keep;
  }

  Future<void> _rememberNote(SharedPreferences prefs, String noteId) async {
    final ids = prefs.getStringList('sent_note_ids') ?? [];
    final dates = prefs.getStringList('sent_note_dates') ?? [];
    ids.add(noteId);
    dates.add(DateTime.now().toIso8601String());
    await prefs.setStringList('sent_note_ids', ids);
    await prefs.setStringList('sent_note_dates', dates);
  }

  /// Choisit une periode parmi celles qui ont des chroniques.
  ///
  /// Celles proposees ces derniers jours passent leur tour : sans cela, deux
  /// semaines sortirait tous les jours, puisque c'est la premiere de la liste
  /// et qu'un journal tenu regulierement en a toujours une.
  Future<MemoryPeriod?> _pickPeriod(
      SharedPreferences prefs, List<Note> notes) async {
    final available = MemoryPeriod.available(notes);
    if (available.isEmpty) return null;

    final seen = prefs.getStringList('sent_periods') ?? [];
    final seenDates = prefs.getStringList('sent_period_dates') ?? [];
    final cutoff = DateTime.now().subtract(const Duration(days: 6));
    final recent = <int>{};
    final keepDays = <String>[];
    final keepDates = <String>[];
    for (var i = 0; i < seen.length && i < seenDates.length; i++) {
      final date = DateTime.tryParse(seenDates[i]);
      if (date != null && date.isAfter(cutoff)) {
        recent.add(int.tryParse(seen[i]) ?? -1);
        keepDays.add(seen[i]);
        keepDates.add(seenDates[i]);
      }
    }

    final fresh =
        available.where((p) => !recent.contains(p.days)).toList();
    final pool = fresh.isNotEmpty ? fresh : available;
    final chosen = pool[Random().nextInt(pool.length)];

    keepDays.add('${chosen.days}');
    keepDates.add(DateTime.now().toIso8601String());
    await prefs.setStringList('sent_periods', keepDays);
    await prefs.setStringList('sent_period_dates', keepDates);
    return chosen;
  }

  /// Le souvenir du soir : une chronique, a lire.
  Future<void> checkAndNotifyMemories({bool force = false}) async {
    if (!_isAvailable || !_memoriesEnabled) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force &&
          !await _isDue(
              prefs, 'last_notif_date', _memoriesHour, _memoriesMinute)) {
        await prefs.setString('last_notif_reason',
            'En attente de $memoriesTimeFormatted');
        return;
      }

      final notes = await NoteService.instance.getAllNotes();
      if (notes.isEmpty) {
        await prefs.setString('last_notif_reason', 'Aucune note disponible');
        return;
      }

      final recent = await _recentlySent(prefs);
      final period = await _pickPeriod(prefs, notes);

      Note note;
      String message;
      if (period != null) {
        final candidates = period
            .matching(notes)
            .where((n) => !recent.contains(n.id))
            .toList();
        final pool =
            candidates.isNotEmpty ? candidates : period.matching(notes);
        note = pool[Random().nextInt(pool.length)];
        message = period.label;
      } else {
        final pool = notes.where((n) => !recent.contains(n.id)).toList();
        final from = pool.isNotEmpty ? pool : notes;
        note = from[Random().nextInt(from.length)];
        message = _memoryMessages[Random().nextInt(_memoryMessages.length)];
      }

      await sendMemoryNotification(note, customMessage: message);
      await _markSent(prefs, 'last_notif_date');
      await _rememberNote(prefs, note.id);
      await prefs.setString('last_notif_reason', 'Souvenir envoyé ($message)');
    } catch (e) {
      debugPrint('Erreur checkAndNotifyMemories: $e');
    }
  }

  /// La seconde notification de la journee : elle ouvre le diaporama des
  /// chroniques d'une meme distance dans le temps.
  Future<void> checkAndNotifySlideshow({bool force = false}) async {
    if (!_isAvailable || !_slideshowEnabled) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!force &&
          !await _isDue(prefs, 'last_slideshow_date', _slideshowHour,
              _slideshowMinute)) {
        return;
      }

      final notes = await NoteService.instance.getAllNotes();
      if (notes.isEmpty) return;

      final period = await _pickPeriod(prefs, notes);
      if (period == null) {
        await prefs.setString(
            'last_slideshow_reason', 'Aucune période à montrer');
        return;
      }

      final matching = period.matching(notes);
      final count = matching.length;

      // Une image du diaporama en avant-garde : c'est elle qui donne envie
      // d'ouvrir, bien plus qu'une ligne de texte.
      String? cover;
      for (final note in matching) {
        for (final path in note.imagePaths) {
          if (await File(path).exists()) {
            cover = path;
            break;
          }
        }
        if (cover != null) break;
      }

      await showLocalNotification(
        id: 'slideshow_${period.days}'.hashCode,
        title: period.label,
        body: count > 1
            ? '$count chroniques à revoir en diaporama'
            : matching.first.title.isNotEmpty
                ? matching.first.title
                : 'Une chronique à revoir',
        // Le prefixe dit a l'application d'ouvrir le diaporama de cette
        // periode plutot qu'une chronique isolee.
        payload: 'memories:${period.days}',
        imagePath: cover,
        bigText: cover != null ? null : _excerpt(matching.first),
      );

      await _markSent(prefs, 'last_slideshow_date');
      await prefs.setString(
          'last_slideshow_reason', 'Diaporama envoyé (${period.title})');
    } catch (e) {
      debugPrint('Erreur checkAndNotifySlideshow: $e');
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
