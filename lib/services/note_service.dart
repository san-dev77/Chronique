import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';
import 'memory_notification_service.dart';

class NoteService {
  static const String _boxName = 'notes';
  static NoteService? _instance;
  static Box? _notesBox;

  bool _autoSyncEnabled = true;

  /// Liste triee gardee en memoire. getAllNotes() re-deserialisait toute la
  /// base a chaque appel, plusieurs fois par navigation.
  List<Note>? _cache;

  /// S'incremente a chaque ecriture. Les ecrans conserves en vie par
  /// l'IndexedStack s'y abonnent pour se rafraichir sans tout recharger.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Une note par son identifiant, sans parcourir toute la liste.
  Note? getNoteById(String id) {
    final raw = _notesBox?.get(id);
    if (raw == null) return null;
    try {
      return Note.fromJson(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  Timer? _notifyTimer;

  void _invalidate() {
    _cache = null;
    // Une synchronisation enregistre les notes une par une. Sans regroupement,
    // chacune declencherait une reconstruction de la liste : on attend la fin
    // de la rafale pour ne prevenir qu'une fois.
    _notifyTimer?.cancel();
    _notifyTimer = Timer(const Duration(milliseconds: 40), () {
      revision.value++;
    });
  }

  // Verrou pour éviter les initialisations concurrentes
  Future<void>? _initOperation;

  NoteService._();

  static NoteService get instance {
    _instance ??= NoteService._();
    return _instance!;
  }

  /// Active/désactive la sync automatique
  void setAutoSync(bool enabled) {
    _autoSyncEnabled = enabled;
  }

  bool get autoSyncEnabled => _autoSyncEnabled;

  Future<void> initialize() async {
    // Par défaut on initialise pour l'utilisateur actuel s'il existe, sinon local
    final userId = AuthService.instance.userId;
    await initializeForUser(userId);
  }

  Future<void> initializeForUser(String? userId) async {
    // Si une initialisation est déjà en cours, on l'attend
    if (_initOperation != null) {
      return _initOperation;
    }

    _initOperation = _performInitialization(userId);
    try {
      await _initOperation;
    } finally {
      _initOperation = null;
    }
  }

  Future<void> _performInitialization(String? userId) async {
    final boxName = userId != null ? 'notes_$userId' : 'notes_local';
    
    // Si une box différente est déjà ouverte, on la ferme d'abord
    if (_notesBox != null && _notesBox!.isOpen && _notesBox!.name != boxName) {
      print('Fermeture de la box Hive : ${_notesBox!.name}');
      await _notesBox!.close();
      _notesBox = null;
    }

    if (_notesBox == null || !_notesBox!.isOpen) {
      _notesBox = await Hive.openBox(boxName);
      _invalidate();
      print('Box Hive ouverte : $boxName');
      
      // MIGRATION : Si on vient de se connecter et que la box est vide,
      // on vérifie si l'ancienne box 'notes' contient des données à migrer
      if (userId != null && _notesBox!.isEmpty) {
        await _migrateLegacyNotes(userId);
      }
    }
  }

  /// Migre les notes de l'ancienne boîte 'notes' vers la nouvelle boîte utilisateur
  Future<void> _migrateLegacyNotes(String userId) async {
    const legacyBoxName = 'notes';
    if (!await Hive.boxExists(legacyBoxName)) return;

    final legacyBox = await Hive.openBox(legacyBoxName);
    if (legacyBox.isEmpty) {
      await legacyBox.close();
      return;
    }

    print('Migration des notes de la box "notes" vers "notes_$userId"...');
    int migratedCount = 0;

    for (var key in legacyBox.keys) {
      final data = legacyBox.get(key);
      if (data != null) {
        // On s'assure que la box cible est toujours ouverte
        if (_notesBox != null && _notesBox!.isOpen) {
          await _notesBox!.put(key, data);
          migratedCount++;
        }
      }
    }

    print('$migratedCount notes migrées avec succès.');

    // Vider et supprimer la boîte legacy pour ne pas migrer deux fois
    await legacyBox.clear();
    await legacyBox.close();
    // On ne retire pas le fichier physiquement, mais il reste vide. 
  }

  Future<void> waitReady() async {
    if (_initOperation != null) {
      await _initOperation;
    }
  }

  Future<void> closeBox() async {
    if (_notesBox != null) {
      await _notesBox!.close();
      _notesBox = null;
    }
  }

  List<Note> getAllNotes() {
    if (_notesBox == null || !_notesBox!.isOpen) {
      print('NoteService: getAllNotes called while box is closed. Returning empty.');
      return [];
    }

    final cached = _cache;
    if (cached != null) return cached;

    final notesData = _notesBox!.values.toList();
    final notes = notesData
        .map((data) => Note.fromJson(Map<String, dynamic>.from(data)))
        .toList();

    // Trier par date de modification (plus récent en premier)
    // Tri sur createdAt : c'est la date affichee sur les cartes. Trier sur
    // modifiedAt donnait un ordre qui ne correspondait a rien de visible.
    notes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _cache = notes;
    return notes;
  }

  /// [touch] a false conserve `modifiedAt`.
  ///
  /// Sans cela, toute ecriture — une mise en favori, une descente depuis le
  /// cloud — remettait la date a maintenant. Consequence : toutes les notes
  /// affichaient « Aujourd'hui » et remontaient en tete de liste.
  /// [syncToCloud] a false enregistre sans renvoyer au cloud.
  ///
  /// Indispensable depuis l'ecoute temps reel : reuploader une note qu'on
  /// vient de recevoir declencherait une boucle sans fin, et chaque tour
  /// reencoderait ses images en base64.
  Future<void> saveNote(Note note,
      {bool isNew = false, bool touch = true, bool syncToCloud = true}) async {
    if (_notesBox == null || !_notesBox!.isOpen) return;

    // Vérifier si c'est une nouvelle note
    final existingNote = _notesBox!.get(note.id);
    final isNewNote = isNew || existingNote == null;

    if (touch) note.modifiedAt = DateTime.now();
    await _notesBox!.put(note.id, note.toJson());
    _invalidate();

    // Envoyer notification si nouvelle note.
    //
    // Seulement pour une note ecrite ici : une note descendue du cloud n'est
    // pas une creation pour cet appareil, et le service de notifications
    // temps reel annonce deja ce qui vient d'ailleurs.
    if (isNewNote && syncToCloud) {
      MemoryNotificationService.instance.sendNoteCreatedNotification(note);
    }

    // Sync auto vers le cloud si connecté
    if (syncToCloud && _autoSyncEnabled && AuthService.instance.isSignedIn) {
      try {
        await CloudSyncService.instance.uploadNote(note);
      } catch (e) {
        print('Echec sync auto note ${note.id}: $e');
      }
    }
  }

  Future<void> deleteNote(String id, {bool syncToCloud = true}) async {
    if (_notesBox == null || !_notesBox!.isOpen) return;

    await _notesBox!.delete(id);
    _invalidate();

    // Sync auto suppression vers le cloud si connecté
    if (syncToCloud && _autoSyncEnabled && AuthService.instance.isSignedIn) {
      try {
        await CloudSyncService.instance.deleteNoteFromCloud(id);
      } catch (e) {
        print('Échec sync auto suppression $id: $e');
      }
    }
  }

  Future<void> deleteAllNotes() async {
    if (_notesBox == null || !_notesBox!.isOpen) return;

    await _notesBox!.clear();
    _invalidate();
  }

  void close() {
    _notesBox?.close();
    _notesBox = null;
  }
}
