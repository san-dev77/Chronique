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
      return [];
    }

    final notesData = _notesBox!.values.toList();
    final notes = notesData
        .map((data) => Note.fromJson(Map<String, dynamic>.from(data)))
        .toList();

    // Trier par date de modification (plus récent en premier)
    notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return notes;
  }

  Future<void> saveNote(Note note, {bool isNew = false}) async {
    if (_notesBox == null || !_notesBox!.isOpen) return;

    // Vérifier si c'est une nouvelle note
    final existingNote = _notesBox!.get(note.id);
    final isNewNote = isNew || existingNote == null;

    note.modifiedAt = DateTime.now();
    await _notesBox!.put(note.id, note.toJson());

    // Envoyer notification si nouvelle note
    if (isNewNote) {
      MemoryNotificationService.instance.sendNoteCreatedNotification(note);
    }

    // Sync auto vers le cloud si connecté
    if (_autoSyncEnabled && AuthService.instance.isSignedIn) {
      try {
        await CloudSyncService.instance.uploadNote(note);
      } catch (e) {
        print('Echec sync auto note ${note.id}: $e');
      }
    }
  }

  Future<void> deleteNote(String id) async {
    if (_notesBox == null || !_notesBox!.isOpen) return;

    await _notesBox!.delete(id);

    // Sync auto suppression vers le cloud si connecté
    if (_autoSyncEnabled && AuthService.instance.isSignedIn) {
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
  }

  void close() {
    _notesBox?.close();
    _notesBox = null;
  }
}
