import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// Ecoute permanente des notes du cloud.
  StreamSubscription<QuerySnapshot>? _liveNotes;

  /// Notes dont il reste des images a rapatrier.
  ///
  /// Les metadonnees arrivent d'abord, les photos ensuite : une note ecrite
  /// sur le telephone s'affiche sur le PC en une seconde, son image une
  /// seconde plus tard, au lieu d'attendre les deux.
  final Set<String> _imageQueue = <String>{};
  bool _draining = false;

  /// Notes dont le document cloud est encore a l'ancien format.
  ///
  /// Tant qu'il n'est pas reecrit, ses images restent collees dedans et
  /// chaque lecture de la liste les retelecharge. On le remet au propre une
  /// fois, et le probleme ne revient plus.
  final Set<String> _legacyNotes = <String>{};

  /// Empreintes deja calculees pendant cette session, par chemin et taille.
  ///
  /// Recompresser une photo coute quelques centaines de millisecondes : on ne
  /// le refait pas a chaque enregistrement de la meme note.
  final Map<String, String> _hashCache = <String, String>{};

  /// Prevenu quand une image differee vient d'arriver.
  final ValueNotifier<int> imagesArrived = ValueNotifier<int>(0);

  /// Nombre de chroniques dont les photos sont encore en route.
  ///
  /// A la premiere connexion sur un appareil, le texte arrive en quelques
  /// secondes et les photos en quelques minutes. Sans ce compteur, l'ecran
  /// ressemble a une application qui a perdu les images.
  final ValueNotifier<int> pendingImages = ValueNotifier<int>(0);

  void _updatePending() => pendingImages.value = _imageQueue.length;

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

  // Un document Firestore est plafonne a 1 Mio. Tant que les photos vivaient
  // dedans, la moindre lecture de la liste des notes retelechargeait plusieurs
  // megaoctets — d'ou les minutes d'attente. Elles vivent maintenant a cote,
  // une par document, nommees par leur empreinte.
  static const int maxImagesPerNote = 3;

  CollectionReference? _imagesOf(String noteId) =>
      _notesCollection?.doc(noteId).collection('images');

  /// Envoie une note : les metadonnees dans le document, les images a cote.
  ///
  /// [forceImages] renvoie les photos meme si la note dit les avoir deja
  /// envoyees. Sert a la reprise de l'ancien format, ou les images etaient
  /// dans le document : leurs empreintes sont connues, mais la sous-collection
  /// est encore vide.
  Future<void> uploadNote(Note note, {bool forceImages = false}) async {
    final notes = _notesCollection;
    if (notes == null) {
      throw Exception('Utilisateur non connecté');
    }

    try {
      final kept = note.imagePaths.take(maxImagesPerNote).toList();
      final budget = ImageStorageService.budgetFor(kept.length);

      // Les empreintes que la note porte deja sont celles que le cloud
      // possede : elles n'ont pas a repartir.
      final known = forceImages ? <String>{} : note.imageHashes.toSet();
      final hashes = <String>[];
      final adopted = <String>[];
      var failed = false;
      for (final path in kept) {
        try {
          final hash = await _uploadImage(note.id, path, known, budget);
          if (hash == null) continue;
          hashes.add(hash);
          // Le fichier local prend le nom derive de l'empreinte. Sans cela,
          // l'appareil ne reconnaitrait pas sa propre photo au retour et la
          // retelechargerait — c'est exactement ce qui remplissait le disque.
          adopted
              .add(await ImageStorageService.instance.adoptAs(path, hash) ?? path);
        } catch (e) {
          // Une photo qui ne passe pas ne doit pas emporter le texte avec
          // elle : la note monte quand meme. L'empreinte n'etant pas
          // enregistree, le prochain enregistrement retentera l'envoi.
          failed = true;
          print('Image non envoyée (note ${note.id}): $e');
        }
      }

      if (failed) {
        // Tant qu'une photo manque a l'appel, on ne retire rien de ce que le
        // cloud possede deja : mieux vaut une image de trop qu'une perdue.
        for (final old in known) {
          if (!hashes.contains(old)) hashes.add(old);
        }
      }

      final data = note.toJson();
      // Un chemin local ne veut rien dire sur un autre appareil.
      data.remove('imagePaths');
      data['imageHashes'] = hashes;
      data['hasImages'] = hashes.isNotEmpty;
      data['imagesCount'] = hashes.length;
      data['updatedAt'] = FieldValue.serverTimestamp();
      data['syncedAt'] = FieldValue.serverTimestamp();
      // Ancien format : les images etaient collees dans le document. On s'en
      // debarrasse au passage, ce qui allege la note pour de bon.
      data['imagesBase64'] = FieldValue.delete();

      await notes.doc(note.id).set(data, SetOptions(merge: true));

      // Les images qu'aucune note ne reclame plus rendent leur quota.
      if (!failed) {
        for (final old in known) {
          if (!hashes.contains(old)) {
            try {
              await _imagesOf(note.id)?.doc(old).delete();
            } catch (_) {
              // Deja partie : rien a faire.
            }
          }
        }
      }

      // La note retient ses empreintes : la synchro suivante saura d'un coup
      // d'oeil qu'elle n'a rien a telecharger.
      //
      // Ses chemins ne sont repointes que si chaque photo a bien suivi : une
      // liste tronquee ou incomplete effacerait des images de la note.
      final complete = !failed &&
          adopted.length == kept.length &&
          kept.length == note.imagePaths.length;
      final movedPaths = complete && !_sameList(note.imagePaths, adopted);

      if (!_sameList(note.imageHashes, hashes) || movedPaths) {
        await NoteService.instance.saveNote(
          note.copyWith(
            imageHashes: hashes,
            imagePaths: movedPaths ? adopted : note.imagePaths,
          ),
          touch: false,
          syncToCloud: false,
        );
      }
    } catch (e) {
      print('Erreur upload note ${note.id}: $e');
      rethrow;
    }
  }

  /// Envoie une image si le cloud ne l'a pas deja. Renvoie son empreinte.
  Future<String?> _uploadImage(
    String noteId,
    String path,
    Set<String> known,
    int budget,
  ) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final raw = await file.readAsBytes();
    final key = '$path:${raw.length}:$budget';

    Uint8List? ready;
    var hash = _hashCache[key];
    if (hash == null) {
      ready = await ImageStorageService.compressForCloud(raw, budget: budget);
      hash = ImageStorageService.fingerprint(ready);
      _hashCache[key] = hash;
    }

    // Deja la-haut : on ne renvoie pas le meme megaoctet.
    if (known.contains(hash)) return hash;

    ready ??= await ImageStorageService.compressForCloud(raw, budget: budget);
    await _imagesOf(noteId)!.doc(hash).set({
      'data': base64Encode(ready),
      'ext': ImageStorageService.extensionOf(ready),
      'bytes': ready.length,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return hash;
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

  /// Telecharge une note depuis Firestore et rebranche ses images.
  Future<Note?> downloadNote(String noteId) async {
    if (_notesCollection == null) return null;

    try {
      final doc = await _notesCollection!.doc(noteId).get();
      if (!doc.exists) return null;
      return await _readCloudNote(doc.data() as Map<String, dynamic>);
    } catch (e) {
      print('Erreur download note $noteId: $e');
      return null;
    }
  }

  /// Telecharge toutes les notes depuis Firestore
  Future<List<Note>> downloadAllNotes() async {
    if (_notesCollection == null) return [];

    try {
      final snapshot = await _notesCollection!.get();

      final notes = <Note>[];
      for (final doc in snapshot.docs) {
        try {
          notes.add(await _readCloudNote(doc.data() as Map<String, dynamic>));
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

  /// Lit un document de note et rebranche les images deja presentes.
  ///
  /// Rien n'est telecharge ici : seules les photos que l'appareil possede
  /// deja sont rattachees. Les autres passent par la file d'attente.
  Future<Note> _readCloudNote(Map<String, dynamic> data) async {
    final note = Note.fromJson(data);

    // Ancien format : les images sont dans le document lui-meme.
    if (note.imageHashes.isEmpty && data['imagesBase64'] is List) {
      return await _readLegacyImages(note, data['imagesBase64'] as List);
    }

    final paths = <String>[];
    for (final hash in note.imageHashes) {
      final local = await ImageStorageService.instance.findCloudImage(hash);
      if (local != null) paths.add(local);
    }
    return note.copyWith(imagePaths: paths);
  }

  /// Reprend les images de l'ancien format, ou elles etaient dans la note.
  Future<Note> _readLegacyImages(Note note, List inline) async {
    // Le document est encore au vieux format : il faudra le reecrire, sinon
    // chaque demarrage retelechargera ses megaoctets.
    _legacyNotes.add(note.id);

    final paths = <String>[];
    final hashes = <String>[];

    for (final entry in inline) {
      if (entry is! String) continue;
      try {
        final bytes = ImageBase64Service.instance.decodeBase64ToBytes(entry);
        if (bytes == null) continue;
        paths.add(await ImageStorageService.instance
            .saveCloudImage(bytes, ImageStorageService.extensionOf(bytes)));
        hashes.add(ImageStorageService.fingerprint(bytes));
      } catch (e) {
        print('Erreur lecture image héritée ${note.id}: $e');
      }
    }

    return note.copyWith(imagePaths: paths, imageHashes: hashes);
  }

  /// Rapatrie les images manquantes d'une note, puis la reenregistre.
  Future<bool> fetchMissingImages(String noteId) async {
    final images = _imagesOf(noteId);
    final note = NoteService.instance.getNoteById(noteId);
    if (images == null || note == null || note.imageHashes.isEmpty) {
      return false;
    }

    final paths = <String>[];
    var arrived = false;

    for (final hash in note.imageHashes) {
      var local = await ImageStorageService.instance.findCloudImage(hash);
      if (local == null) {
        try {
          final doc = await images.doc(hash).get();
          final data = doc.data() as Map<String, dynamic>?;
          final payload = data?['data'] as String?;
          if (payload != null) {
            final bytes =
                ImageBase64Service.instance.decodeBase64ToBytes(payload);
            if (bytes != null) {
              local = await ImageStorageService.instance.saveCloudImage(
                bytes,
                (data?['ext'] as String?) ??
                    ImageStorageService.extensionOf(bytes),
              );
              arrived = true;
            }
          }
        } catch (e) {
          print('Erreur téléchargement image $hash: $e');
        }
      }
      if (local != null) paths.add(local);
    }

    if (arrived) {
      await NoteService.instance.saveNote(
        note.copyWith(imagePaths: paths),
        touch: false,
        syncToCloud: false,
      );
    }
    return arrived;
  }

  /// Traite la file d'attente des images, une note apres l'autre.
  Future<void> _drainImages() async {
    if (_draining) return;
    _draining = true;
    try {
      var arrived = 0;
      while (_imageQueue.isNotEmpty) {
        // L'ordre se calcule une fois par passe, pas a chaque image. La
        // premiere version relisait toute la file dans Hive avant de servir
        // chaque photo : avec cent notes en attente, cela faisait dix mille
        // deserialisations sur le thread d'interface, et Android affichait
        // « l'application ne repond pas ».
        for (final id in _orderedQueue()) {
          if (!_imageQueue.remove(id)) continue;
          _updatePending();
          try {
            if (await fetchMissingImages(id)) arrived++;
          } catch (e) {
            print('Erreur hydratation note $id: $e');
          }
        }
      }
      if (arrived > 0) imagesArrived.value++;
      await _rewriteLegacyNotes();
    } finally {
      _draining = false;
      _updatePending();
    }
  }

  /// Remet au propre les documents restes a l'ancien format.
  ///
  /// Leurs images repartent dans la sous-collection — d'ou [forceImages] : la
  /// note connait leurs empreintes, mais le cloud ne les a qu'en vrac dans le
  /// document. Une fois reecrit, il ne pese plus que quelques octets.
  Future<void> _rewriteLegacyNotes() async {
    while (_legacyNotes.isNotEmpty) {
      final id = _legacyNotes.first;
      _legacyNotes.remove(id);
      final note = NoteService.instance.getNoteById(id);
      if (note == null) continue;

      // Garde-fou : reecrire le document retire les images qu'il contenait.
      // Si les fichiers ne sont pas tous presents ici, on n'y touche pas —
      // sinon la photo disparaitrait du cloud sans copie ailleurs.
      if (note.imagePaths.length < note.imageHashes.length) continue;

      try {
        await uploadNote(note, forceImages: true);
      } catch (e) {
        print('Reprise du format impossible pour $id: $e');
      }
    }
  }

  /// La file, des plus recentes aux plus anciennes.
  ///
  /// La file suit l'ordre dans lequel Firestore renvoie les documents, qui
  /// n'a rien a voir avec l'ordre d'affichage. Les images apparaissaient donc
  /// au hasard dans la grille — souvent par le bas, puisque la liste est
  /// triee du plus recent au plus ancien. En servant les plus recentes
  /// d'abord, elles se remplissent de haut en bas, dans l'ordre ou l'oeil
  /// les attend.
  ///
  /// La date est lue une seule fois par note : c'est ce qui coute, pas le
  /// tri.
  List<String> _orderedQueue() {
    final dated = _imageQueue
        .map((id) => (
              id: id,
              date: NoteService.instance.getNoteById(id)?.createdAt,
            ))
        .toList()
      ..sort((a, b) {
        if (a.date == null) return b.date == null ? 0 : 1;
        if (b.date == null) return -1;
        return b.date!.compareTo(a.date!);
      });
    return dated.map((e) => e.id).toList();
  }

  /// Il manque des photos a cette note.
  bool _needsImages(Note note) =>
      note.imagePaths.length < note.imageHashes.length;

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Adopte les images locales d'une note deja synchronisee.
  ///
  /// Meme version des deux cotes et meme nombre de photos : les fichiers
  /// presents sont les bons, seul leur nom date d'avant. Les recopier sous le
  /// nom attendu evite de retelecharger ce que l'appareil possede deja.
  Future<bool> _adoptLocalImages(Note local, Note cloud) async {
    if (cloud.imageHashes.isEmpty) return false;
    if (local.imageHashes.isNotEmpty) return false;
    if (local.imagePaths.length != cloud.imageHashes.length) return false;

    final paths = <String>[];
    for (var i = 0; i < cloud.imageHashes.length; i++) {
      final adopted = await ImageStorageService.instance
          .adoptAs(local.imagePaths[i], cloud.imageHashes[i]);
      if (adopted == null) return false;
      paths.add(adopted);
    }

    await NoteService.instance.saveNote(
      local.copyWith(imagePaths: paths, imageHashes: cloud.imageHashes),
      touch: false,
      syncToCloud: false,
    );
    return true;
  }

  // ============================================================= temps reel

  bool get isLive => _liveNotes != null;

  /// Suit les notes du cloud en continu.
  ///
  /// C'est ce qui remplace les boutons : une note ecrite sur le telephone
  /// arrive sur le PC d'elle-meme, en une seconde, sans rien actualiser.
  void startLiveSync() {
    if (_liveNotes != null) return;
    final notes = _notesCollection;
    if (notes == null) return;

    _liveNotes = notes.snapshots().listen(
      _onRemoteChanges,
      onError: (Object e) => print('Écoute cloud interrompue: $e'),
    );
  }

  Future<void> stopLiveSync() async {
    await _liveNotes?.cancel();
    _liveNotes = null;
    _imageQueue.clear();
    _updatePending();
  }

  Future<void> _onRemoteChanges(QuerySnapshot snapshot) async {
    for (final change in snapshot.docChanges) {
      try {
        if (change.type == DocumentChangeType.removed) {
          // Effacee ailleurs : on suit, sans la renvoyer au cloud.
          if (NoteService.instance.getNoteById(change.doc.id) != null) {
            await NoteService.instance
                .deleteNote(change.doc.id, syncToCloud: false);
          }
          continue;
        }

        final data = change.doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        await _applyRemote(await _readCloudNote(data));
      } catch (e) {
        print('Erreur application note ${change.doc.id}: $e');
      }
    }

    // Les images arrivent apres, sans retenir l'affichage des notes.
    _drainImages();
  }

  /// Confronte une note du cloud a sa version locale.
  Future<void> _applyRemote(Note cloud) async {
    final local = NoteService.instance.getNoteById(cloud.id);

    if (local == null) {
      await NoteService.instance
          .saveNote(cloud, touch: false, syncToCloud: false);
      if (_needsImages(cloud)) {
        _imageQueue.add(cloud.id);
        _updatePending();
      }
      return;
    }

    if (local.modifiedAt.isAfter(cloud.modifiedAt)) {
      // Le local est plus frais : c'est lui qui monte. Le document revient
      // alors avec la meme date, et l'echange s'arrete la.
      await uploadNote(local);
      return;
    }

    if (cloud.modifiedAt.isAfter(local.modifiedAt)) {
      await NoteService.instance
          .saveNote(cloud, touch: false, syncToCloud: false);
      if (_needsImages(cloud)) {
        _imageQueue.add(cloud.id);
        _updatePending();
      }
      return;
    }

    // Meme version des deux cotes : seules les images peuvent manquer.
    if (local.imageHashes.isEmpty && cloud.imageHashes.isNotEmpty) {
      // L'ancien format a deja ecrit ses fichiers en les lisant : si ses
      // chemins sont plus complets que ceux d'ici, ce sont eux qui valent.
      if (cloud.imagePaths.length > local.imagePaths.length) {
        await NoteService.instance.saveNote(
          local.copyWith(
            imagePaths: cloud.imagePaths,
            imageHashes: cloud.imageHashes,
          ),
          touch: false,
          syncToCloud: false,
        );
        return;
      }

      if (await _adoptLocalImages(local, cloud)) return;
      await NoteService.instance.saveNote(
        local.copyWith(imageHashes: cloud.imageHashes),
        touch: false,
        syncToCloud: false,
      );
      _imageQueue.add(cloud.id);
      _updatePending();
    } else if (_needsImages(cloud)) {
      _imageQueue.add(cloud.id);
      _updatePending();
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
      
      // Sync image si présente. Une etincelle n'en a qu'une : elle reste
      // dans le document, mais reduite — un document plafonne a 1 Mio et le
      // base64 gonfle de 33 %.
      if (spark.imagePath != null) {
        final file = File(spark.imagePath!);
        if (await file.exists()) {
          final ready = await ImageStorageService.compressForCloud(
            await file.readAsBytes(),
            budget: 500 * 1024,
          );
          sparkData['imagePhotoBase64'] = base64Encode(ready);
          sparkData['imageExt'] = ImageStorageService.extensionOf(ready);
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
          
          // Hydrater l'image si présente. Le nom du fichier derive de son
          // contenu : une image deja recue est reutilisee au lieu d'etre
          // recopiee a chaque synchronisation.
          if (data.containsKey('imagePhotoBase64')) {
            final payload = data['imagePhotoBase64'] as String;
            final bytes =
                ImageBase64Service.instance.decodeBase64ToBytes(payload);
            if (bytes != null) {
              final localPath = await ImageStorageService.instance
                  .saveCloudImage(
                      bytes,
                      (data['imageExt'] as String?) ??
                          ImageStorageService.extensionOf(bytes));
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

  /// Synchronisation en cours, partagee entre les appelants.
  Future<SyncReport>? _running;

  /// Synchronisation bidirectionnelle complète.
  ///
  /// Deux appels simultanes ne s'annulent plus : le second attend le premier.
  /// L'ecran de connexion et l'ecoute du compte la demandaient tous les deux,
  /// et l'un des deux echouait sur « Synchronisation déjà en cours ».
  Future<SyncReport> syncAll() {
    final running = _running;
    if (running != null) return running;
    final started = _syncAll();
    _running = started;
    return started.whenComplete(() => _running = null);
  }

  Future<SyncReport> _syncAll() async {
    if (_notesCollection == null) {
      throw Exception('Utilisateur non connecté');
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

          if (cloudNote == null) {
            // Seulement en local : elle monte.
            await uploadNote(localNote!);
            report.uploadedItems++;
          } else if (localNote == null) {
            await _applyRemote(cloudNote);
            report.downloadedItems++;
          } else if (localNote.modifiedAt.isAfter(cloudNote.modifiedAt) ||
              (localNote.imagePaths.isNotEmpty &&
                  cloudNote.imageHashes.isEmpty)) {
            // Plus fraiche en local, ou le cloud n'a pas encore ses images.
            await uploadNote(localNote);
            report.uploadedItems++;
          } else if (cloudNote.modifiedAt.isAfter(localNote.modifiedAt)) {
            await _applyRemote(cloudNote);
            report.downloadedItems++;
          } else {
            // Meme version : _applyRemote ne regarde plus que les images.
            await _applyRemote(cloudNote);
            report.unchangedItems++;
          }
        } catch (e) {
          print('Erreur sync note $noteId: $e');
          report.failedItems++;
          report.errorMessage =
              'Certains éléments n\'ont pas pu être synchronisés.';
        }
      }

      // Les photos manquantes arrivent en arriere-plan : les notes sont
      // lisibles tout de suite, et l'ecran se rafraichit a leur arrivee.
      _drainImages();

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
