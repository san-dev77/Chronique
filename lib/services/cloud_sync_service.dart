import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import 'auth_service.dart';
import 'note_service.dart';
import 'spark_service.dart';
import 'image_base64_service.dart';
import 'image_storage_service.dart';
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
  /// Inclut désormais les images encodées en Base64
  Future<void> uploadNote(Note note) async {
    if (_notesCollection == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      final noteData = note.toJson();

      // Encode les images en Base64 pour le cloud
      if (note.imagePaths.isNotEmpty) {
        final imagesBase64 = await ImageBase64Service.instance
            .encodeMultipleImages(note.imagePaths, maxImages: 5);
        noteData['imagesBase64'] = imagesBase64;
      }
      
      // On retire quand même les chemins locaux car ils ne sont pas valides sur un autre appareil
      noteData.remove('imagePaths');

      // Ajouter les métadonnées cloud
      noteData['updatedAt'] = FieldValue.serverTimestamp();
      noteData['syncedAt'] = FieldValue.serverTimestamp();
      noteData['hasImages'] = note.imagePaths.isNotEmpty;
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

  /// Télécharge une note depuis Firestore et restaure les images
  Future<Note?> downloadNote(String noteId) async {
    if (_notesCollection == null) return null;

    try {
      final doc = await _notesCollection!.doc(noteId).get();
      if (!doc.exists) return null;

      final data = doc.data() as Map<String, dynamic>;
      
      // Créer la note de base
      Note note = Note.fromJson(data);
      
      // Restaurer les images si présentes
      return await _hydrateNoteImages(note, data);
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
          Note note = Note.fromJson(data);
          
          // Hydrater les images
          final hydratedNote = await _hydrateNoteImages(note, data);
          notes.add(hydratedNote);
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

  /// Helper pour restaurer les images Base64 en fichiers locaux
  Future<Note> _hydrateNoteImages(Note note, Map<String, dynamic> cloudData) async {
    if (!cloudData.containsKey('imagesBase64')) return note;
    
    final List<dynamic> imagesBase64 = cloudData['imagesBase64'];
    if (imagesBase64.isEmpty) return note;

    final newLocalPaths = <String>[];
    
    for (String base64 in imagesBase64) {
      try {
        final bytes = ImageBase64Service.instance.decodeBase64ToBytes(base64);
        if (bytes != null) {
          // Détecter l'extension
          String ext = 'jpg';
          if (base64.contains('image/png')) ext = 'png';
          else if (base64.contains('image/webp')) ext = 'webp';
          
          final localPath = await ImageStorageService.instance.saveImageFromBytes(bytes, ext);
          newLocalPaths.add(localPath);
        }
      } catch (e) {
        print('Erreur hydration image note ${note.id}: $e');
      }
    }

    if (newLocalPaths.isNotEmpty) {
      return note.copyWith(imagePaths: newLocalPaths);
    }
    
    return note;
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
      
      // Sync image si présente
      if (spark.imagePath != null) {
        final base64 = await ImageBase64Service.instance.encodeImageToBase64(spark.imagePath!);
        if (base64 != null) {
          sparkData['imagePhotoBase64'] = base64;
        }
      }
      
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
          Spark spark = Spark.fromJson(data);
          
          // Hydrater l'image si présente
          if (data.containsKey('imagePhotoBase64')) {
            final base64 = data['imagePhotoBase64'] as String;
            final bytes = ImageBase64Service.instance.decodeBase64ToBytes(base64);
            if (bytes != null) {
              String ext = 'jpg';
              if (base64.contains('image/png')) ext = 'png';
              final localPath = await ImageStorageService.instance.saveImageFromBytes(bytes, ext);
              spark = spark.copyWith(imagePath: localPath);
            }
          }
          
          sparks.add(spark);
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
        try {
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
            
            // CAS SPÉCIAL MIGRATION : Si local a des images mais le cloud n'en a pas encore,
            // on force l'upload même si les dates sont identiques.
            bool cloudMissingImages = localNote.imagePaths.isNotEmpty && cloudNote.imagePaths.isEmpty;

            if (localNote.modifiedAt.isAfter(cloudNote.modifiedAt) || cloudMissingImages) {
              // Local plus récent ou images à migrer → uploader
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
        } catch (e) {
          print('Erreur sync note $noteId: $e');
          report.failedItems++;
          report.errorMessage = 'Certains éléments n\'ont pas pu être synchronisés (taille possiblement trop grande).';
        }
      }

      // --- SYNC SPARKS ---
      final localSparks = SparkService.instance.getAllSparks();
      final cloudSparks = await downloadAllSparks();

      final localSparksMap = {for (var s in localSparks) s.id: s};
      final cloudSparksMap = {for (var s in cloudSparks) s.id: s};
      final allSparkIds = {...localSparksMap.keys, ...cloudSparksMap.keys};

      for (final sparkId in allSparkIds) {
        try {
          final localSpark = localSparksMap[sparkId];
          final cloudSpark = cloudSparksMap[sparkId];

          if (localSpark == null && cloudSpark != null) {
            await SparkService.instance.saveSpark(cloudSpark, skipCloud: true);
            report.downloadedItems++;
          } else if (localSpark != null && cloudSpark == null) {
            await uploadSpark(localSpark);
            report.uploadedItems++;
          } else if (localSpark != null && cloudSpark != null) {
            // CAS SPÉCIAL MIGRATION ÉTINCELLES
            bool cloudMissingImage = localSpark.imagePath != null && cloudSpark.imagePath == null;

            if (localSpark.modifiedAt.isAfter(cloudSpark.modifiedAt) || cloudMissingImage) {
              await uploadSpark(localSpark);
              report.uploadedItems++;
            } else if (cloudSpark.modifiedAt.isAfter(localSpark.modifiedAt)) {
              await SparkService.instance.saveSpark(cloudSpark, skipCloud: true);
              report.downloadedItems++;
            } else {
              report.unchangedItems++;
            }
          }
        } catch (e) {
          print('Erreur sync spark $sparkId: $e');
          report.failedItems++;
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
  int failedItems = 0;
  String? errorMessage;

  String getSummary() {
    if (errorMessage != null && totalSynced == 0 && failedItems == 0) {
      return 'Échec critique: $errorMessage';
    }

    final parts = <String>[];

    if (uploadedItems > 0) {
      parts.add('⬆️ $uploadedItems envoyé(s)');
    }

    if (downloadedItems > 0) {
      parts.add('⬇️ $downloadedItems reçu(s)');
    }

    if (failedItems > 0) {
      parts.add('❌ $failedItems échec(s)');
    }

    if (unchangedItems > 0 && parts.isEmpty) {
      parts.add('✓ Déjà à jour');
    }

    if (parts.isEmpty && errorMessage == null) {
      return '✅ Synchronisé';
    }
    
    if (errorMessage != null) {
      parts.add('⚠️ Note: $errorMessage');
    }

    return parts.join('\n');
  }

  int get totalSynced => uploadedItems + downloadedItems;
}
