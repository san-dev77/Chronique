import 'package:hive/hive.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'cloud_sync_service.dart';

class NoteService {
  static const String _boxName = 'notes';
  static NoteService? _instance;
  static Box? _notesBox;

  bool _autoSyncEnabled = true;

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
    if (_notesBox == null) {
      _notesBox = await Hive.openBox(_boxName);
    }
  }

  List<Note> getAllNotes() {
    if (_notesBox == null) {
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

  Future<void> saveNote(Note note) async {
    if (_notesBox == null) return;

    note.modifiedAt = DateTime.now();
    await _notesBox!.put(note.id, note.toJson());

    // Sync auto vers le cloud si connecté
    if (_autoSyncEnabled && AuthService.instance.isSignedIn) {
      try {
        await CloudSyncService.instance.uploadNote(note);
      } catch (e) {
        print('Échec sync auto note ${note.id}: $e');
        // Continue même si sync échoue (offline-first)
      }
    }
  }

  Future<void> deleteNote(String id) async {
    if (_notesBox == null) return;

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
    if (_notesBox == null) return;

    await _notesBox!.clear();
  }

  void close() {
    _notesBox?.close();
    _notesBox = null;
  }
}
