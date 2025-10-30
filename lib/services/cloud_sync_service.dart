import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'note_service.dart';

/// Service de synchronisation cloud avec Firestore
class CloudSyncService {
  static CloudSyncService? _instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  CloudSyncService._();

  static CloudSyncService get instance {
    _instance ??= CloudSyncService._();
    return _instance!;
  }

  /// Vérifie si une sync est en cours
  bool get isSyncing => _isSyncing;

  /// Dernière date de sync
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Collection des notes de l'utilisateur
  CollectionReference? get _notesCollection {
    final userId = AuthService.instance.userId;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('notes');
  }

  /// Upload une note vers Firestore
  /// IMPORTANT: Les chemins d'images sont exclus (images restent en local)
  Future<void> uploadNote(Note note) async {
    if (_notesCollection == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      final noteData = note.toJson();

      // SUPPRIME les chemins d'images pour ne pas sync (images en local uniquement)
      noteData.remove('imagePaths');

      // Ajouter les métadonnées cloud
      noteData['updatedAt'] = FieldValue.serverTimestamp();
      noteData['syncedAt'] = FieldValue.serverTimestamp();
      noteData['hasImages'] = note.imagePaths.isNotEmpty; // Juste un flag
      noteData['imagesCount'] = note.imagePaths.length;

      await _notesCollection!.doc(note.id).set(noteData);
    } catch (e) {
      print('Erreur upload note ${note.id}: $e');
      rethrow;
    }
  }

  /// Upload toutes les notes locales vers Firestore
  Future<int> uploadAllNotes() async {
    if (_notesCollection == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      final localNotes = NoteService.instance.getAllNotes();
      int uploadedCount = 0;

      for (final note in localNotes) {
        try {
          await uploadNote(note);
          uploadedCount++;
        } catch (e) {
          print('Échec upload note ${note.id}: $e');
        }
      }

      return uploadedCount;
    } catch (e) {
      print('Erreur upload all notes: $e');
      rethrow;
    }
  }

  /// Télécharge une note depuis Firestore
  /// IMPORTANT: Les images ne sont pas téléchargées (restent en local)
  Future<Note?> downloadNote(String noteId) async {
    if (_notesCollection == null) return null;

    try {
      final doc = await _notesCollection!.doc(noteId).get();

      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;

      // S'assurer que imagePaths existe (vide par défaut)
      if (!data.containsKey('imagePaths')) {
        data['imagePaths'] = [];
      }

      return Note.fromJson(data);
    } catch (e) {
      print('Erreur download note $noteId: $e');
      return null;
    }
  }

  /// Télécharge toutes les notes depuis Firestore
  Future<List<Note>> downloadAllNotes() async {
    if (_notesCollection == null) return [];

    try {
      final snapshot = await _notesCollection!.get();

      final notes = <Note>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          notes.add(Note.fromJson(data));
        } catch (e) {
          print('Erreur parsing note ${doc.id}: $e');
        }
      }

      return notes;
    } catch (e) {
      print('Erreur download all notes: $e');
      rethrow;
    }
  }

  /// Supprime une note de Firestore
  Future<void> deleteNoteFromCloud(String noteId) async {
    if (_notesCollection == null) return;

    try {
      await _notesCollection!.doc(noteId).delete();
    } catch (e) {
      print('Erreur suppression note cloud $noteId: $e');
      rethrow;
    }
  }

  /// Synchronisation bidirectionnelle complète
  Future<SyncReport> syncAll() async {
    if (_notesCollection == null) {
      throw Exception('Utilisateur non connecté');
    }

    if (_isSyncing) {
      throw Exception('Synchronisation déjà en cours');
    }

    _isSyncing = true;
    final report = SyncReport();

    try {
      // 1. Récupérer les notes locales et cloud
      final localNotes = NoteService.instance.getAllNotes();
      final cloudNotes = await downloadAllNotes();

      report.totalLocalNotes = localNotes.length;
      report.totalCloudNotes = cloudNotes.length;

      // 2. Créer des maps pour faciliter la comparaison
      final localNotesMap = {for (var note in localNotes) note.id: note};
      final cloudNotesMap = {for (var note in cloudNotes) note.id: note};

      // 3. Identifier les notes à synchroniser
      final allNoteIds = {...localNotesMap.keys, ...cloudNotesMap.keys};

      for (final noteId in allNoteIds) {
        final localNote = localNotesMap[noteId];
        final cloudNote = cloudNotesMap[noteId];

        if (localNote == null && cloudNote != null) {
          // Note existe seulement dans le cloud → télécharger
          await NoteService.instance.saveNote(cloudNote);
          report.downloadedNotes++;
        } else if (localNote != null && cloudNote == null) {
          // Note existe seulement localement → uploader
          await uploadNote(localNote);
          report.uploadedNotes++;
        } else if (localNote != null && cloudNote != null) {
          // Note existe des deux côtés → comparer dates
          if (localNote.modifiedAt.isAfter(cloudNote.modifiedAt)) {
            // Local plus récent → uploader
            await uploadNote(localNote);
            report.uploadedNotes++;
          } else if (cloudNote.modifiedAt.isAfter(localNote.modifiedAt)) {
            // Cloud plus récent → télécharger
            await NoteService.instance.saveNote(cloudNote);
            report.downloadedNotes++;
          } else {
            // Identiques
            report.unchangedNotes++;
          }
        }
      }

      _lastSyncTime = DateTime.now();
      report.success = true;
    } catch (e) {
      report.success = false;
      report.errorMessage = e.toString();
      print('Erreur sync: $e');
    } finally {
      _isSyncing = false;
    }

    return report;
  }

  /// Écoute les changements cloud en temps réel
  Stream<List<Note>> watchNotes() {
    if (_notesCollection == null) {
      return Stream.value([]);
    }

    return _notesCollection!.snapshots().map((snapshot) {
      final notes = <Note>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          notes.add(Note.fromJson(data));
        } catch (e) {
          print('Erreur parsing note ${doc.id}: $e');
        }
      }
      return notes;
    });
  }

  /// Supprime toutes les notes cloud (pour déconnexion complète)
  Future<void> deleteAllCloudNotes() async {
    if (_notesCollection == null) return;

    try {
      final snapshot = await _notesCollection!.get();

      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      print('Erreur suppression toutes notes cloud: $e');
      rethrow;
    }
  }
}

/// Rapport de synchronisation
class SyncReport {
  bool success = false;
  int totalLocalNotes = 0;
  int totalCloudNotes = 0;
  int uploadedNotes = 0;
  int downloadedNotes = 0;
  int unchangedNotes = 0;
  String? errorMessage;

  String getSummary() {
    if (!success) {
      return 'Échec: ${errorMessage ?? "Erreur inconnue"}';
    }

    final parts = <String>[];

    if (uploadedNotes > 0) {
      parts.add('⬆️ $uploadedNotes uploadée(s)');
    }

    if (downloadedNotes > 0) {
      parts.add('⬇️ $downloadedNotes téléchargée(s)');
    }

    if (unchangedNotes > 0) {
      parts.add('✓ $unchangedNotes à jour');
    }

    if (parts.isEmpty) {
      return '✅ Tout est synchronisé';
    }

    return parts.join('\n');
  }

  int get totalSynced => uploadedNotes + downloadedNotes;
}
