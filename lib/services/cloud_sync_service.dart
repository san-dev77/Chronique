import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'note_service.dart';
import 'spark_service.dart';
import '../models/spark.dart';

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

  /// Collection des étincelles de l'utilisateur
  CollectionReference? get _sparksCollection {
    final userId = AuthService.instance.userId;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('sparks');
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

  // --- METHODS FOR SPARKS ---

  /// Upload une étincelle vers Firestore
  Future<void> uploadSpark(Spark spark) async {
    if (_sparksCollection == null) return;

    try {
      final sparkData = spark.toJson();
      // On garde l'imagePath tel quel car c'est un chemin local,
      // On pourrait aussi le supprimer comme pour les notes si on veut économiser de l'espace cloud
      // pour des chemins qui ne seront plus valides ailleurs. 
      // Mais pour les étincelles, l'image est plus "fugace".
      sparkData.remove('imagePath'); 

      sparkData['updatedAt'] = FieldValue.serverTimestamp();
      sparkData['syncedAt'] = FieldValue.serverTimestamp();

      await _sparksCollection!.doc(spark.id).set(sparkData);
    } catch (e) {
      print('Erreur upload spark ${spark.id}: $e');
      rethrow;
    }
  }

  /// Télécharge toutes les étincelles depuis Firestore
  Future<List<Spark>> downloadAllSparks() async {
    if (_sparksCollection == null) return [];

    try {
      final snapshot = await _sparksCollection!.get();
      final sparks = <Spark>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>;
          sparks.add(Spark.fromJson(data));
        } catch (e) {
          print('Erreur parsing spark ${doc.id}: $e');
        }
      }
      return sparks;
    } catch (e) {
      print('Erreur download all sparks: $e');
      rethrow;
    }
  }

  /// Supprime une étincelle de Firestore
  Future<void> deleteSparkFromCloud(String sparkId) async {
    if (_sparksCollection == null) return;
    try {
      await _sparksCollection!.doc(sparkId).delete();
    } catch (e) {
      print('Erreur suppression spark cloud $sparkId: $e');
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
      // Attendre que la base locale soit prête (isolation)
      await NoteService.instance.waitReady();

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
          report.downloadedItems++;
        } else if (localNote != null && cloudNote == null) {
          // Note existe seulement localement → uploader
          await uploadNote(localNote);
          report.uploadedItems++;
        } else if (localNote != null && cloudNote != null) {
          // Note existe des deux côtés → comparer dates
          if (localNote.modifiedAt.isAfter(cloudNote.modifiedAt)) {
            // Local plus récent → uploader
            await uploadNote(localNote);
            report.uploadedItems++;
          } else if (cloudNote.modifiedAt.isAfter(localNote.modifiedAt)) {
            // Cloud plus récent → télécharger
            await NoteService.instance.saveNote(cloudNote);
            report.downloadedItems++;
          } else {
            // Identiques
            report.unchangedItems++;
          }
        }
      }

      // --- SYNC SPARKS ---
      final localSparks = SparkService.instance.getAllSparks();
      final cloudSparks = await downloadAllSparks();

      final localSparksMap = {for (var s in localSparks) s.id: s};
      final cloudSparksMap = {for (var s in cloudSparks) s.id: s};
      final allSparkIds = {...localSparksMap.keys, ...cloudSparksMap.keys};

      for (final sparkId in allSparkIds) {
        final localSpark = localSparksMap[sparkId];
        final cloudSpark = cloudSparksMap[sparkId];

        if (localSpark == null && cloudSpark != null) {
          await SparkService.instance.saveSpark(cloudSpark, skipCloud: true);
          report.downloadedItems++;
        } else if (localSpark != null && cloudSpark == null) {
          await uploadSpark(localSpark);
          report.uploadedItems++;
        } else if (localSpark != null && cloudSpark != null) {
          if (localSpark.modifiedAt.isAfter(cloudSpark.modifiedAt)) {
            await uploadSpark(localSpark);
            report.uploadedItems++;
          } else if (cloudSpark.modifiedAt.isAfter(localSpark.modifiedAt)) {
            await SparkService.instance.saveSpark(cloudSpark, skipCloud: true);
            report.downloadedItems++;
          } else {
            report.unchangedItems++;
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
  int uploadedItems = 0;
  int downloadedItems = 0;
  int unchangedItems = 0;
  String? errorMessage;

  String getSummary() {
    if (!success) {
      return 'Échec: ${errorMessage ?? "Erreur inconnue"}';
    }

    final parts = <String>[];

    if (uploadedItems > 0) {
      parts.add('⬆️ $uploadedItems uploadé(s)');
    }

    if (downloadedItems > 0) {
      parts.add('⬇️ $downloadedItems téléchargé(s)');
    }

    if (unchangedItems > 0) {
      parts.add('✓ $unchangedItems à jour');
    }

    if (parts.isEmpty) {
      return '✅ Tout est synchronisé';
    }

    return parts.join('\n');
  }

  int get totalSynced => uploadedItems + downloadedItems;
}
