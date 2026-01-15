import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';
import '../models/shared_note.dart';
import '../models/reaction.dart';
import '../models/app_notification.dart';
import 'auth_service.dart';
import 'image_base64_service.dart';
import 'realtime_notification_service.dart';

/// Modèle représentant un membre de l'application
class AppMember {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? photoBase64;
  final int? profileColor;

  AppMember({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.photoBase64,
    this.profileColor,
  });

  factory AppMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppMember(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? data['email'] ?? 'Utilisateur',
      photoUrl: data['photoURL'],
      photoBase64: data['photoBase64'],
      profileColor: data['profileColor'],
    );
  }
}

/// Service de partage de notes entre utilisateurs
class SharingService {
  static SharingService? _instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SharingService._();

  static SharingService get instance {
    _instance ??= SharingService._();
    return _instance!;
  }

  /// Collection des notes partagées
  CollectionReference get _sharedNotesCollection {
    return _firestore.collection('shared_notes');
  }

  /// Collection des utilisateurs
  CollectionReference get _usersCollection {
    return _firestore.collection('users');
  }

  // ============================================================
  // GESTION DES MEMBRES
  // ============================================================

  /// Récupère tous les membres de l'application (sauf l'utilisateur actuel)
  Future<List<AppMember>> getAllMembers() async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];

    try {
      final snapshot = await _usersCollection.get();
      
      return snapshot.docs
          .where((doc) => doc.id != currentUser.uid)
          .map((doc) => AppMember.fromFirestore(doc))
          .where((member) => member.email.isNotEmpty)
          .toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));
    } catch (e) {
      debugPrint('Erreur récupération membres: $e');
      return [];
    }
  }

  /// Enregistre l'utilisateur actuel dans la collection users (à appeler à la connexion)
  Future<void> registerCurrentUser({
    String? name,
    String? photoBase64,
    int? profileColor,
  }) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    final displayName = name ?? currentUser.displayName ?? 'Utilisateur';

    try {
      final data = {
        'email': currentUser.email?.toLowerCase(),
        'displayName': displayName,
        'photoURL': currentUser.photoURL,
        'lastSeen': FieldValue.serverTimestamp(),
      };

      if (photoBase64 != null) {
        data['photoBase64'] = photoBase64;
      }
      
      if (profileColor != null) {
        data['profileColor'] = profileColor;
      }

      await _usersCollection.doc(currentUser.uid).set(data, SetOptions(merge: true));
      debugPrint('Firestore: Profil utilisateur enregistre ($displayName)');
    } catch (e) {
      debugPrint('Erreur enregistrement utilisateur: $e');
    }
  }

  /// Met à jour les éléments de profil spécifiques (Image Base64 ou Couleur)
  Future<void> updateProfileData({String? photoBase64, int? profileColor}) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    try {
      final Map<String, dynamic> data = {};
      if (photoBase64 != null) data['photoBase64'] = photoBase64;
      if (profileColor != null) data['profileColor'] = profileColor;
      
      if (data.isNotEmpty) {
        await _usersCollection.doc(currentUser.uid).update(data);
        debugPrint('Firestore: Profil mis à jour (${data.keys.join(", ")})');
      }
    } catch (e) {
      debugPrint('Erreur updateProfileData: $e');
      rethrow;
    }
  }

  // ============================================================
  // PARTAGE DE NOTES
  // ============================================================

  /// Partage une note avec un membre (via objet AppMember)
  Future<SharedNote?> shareNoteToMember(Note note, AppMember member) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Vous devez être connecté pour partager une note');
    }

    // Encoder les images en Base64
    final imagesBase64 = await ImageBase64Service.instance
        .encodeMultipleImages(note.imagePaths);

    // Créer la note partagée
    final sharedNoteId = _sharedNotesCollection.doc().id;
    final sharedNote = SharedNote(
      id: sharedNoteId,
      noteId: note.id,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      senderName: currentUser.displayName ?? 'Utilisateur',
      recipientId: member.uid,
      recipientEmail: member.email,
      recipientName: member.displayName,
      title: note.title,
      content: note.content,
      formattedContent: note.formattedContent,
      imagesBase64: imagesBase64,
      color: note.color.value,
      sharedAt: DateTime.now(),
      reactions: [],
      isRead: false,
    );

    // Sauvegarder dans Firestore
    await _sharedNotesCollection.doc(sharedNoteId).set(sharedNote.toJson());

    // Émettre une notification
    await _notify(
      recipientId: member.uid,
      type: NotificationType.share,
      sharedNoteId: sharedNoteId,
      title: 'Nouvelle story reçue',
      body: '${currentUser.displayName ?? "Quelqu'un"} vous a partagé une story : ${note.title}',
    );

    return sharedNote;
  }

  /// Partage une note avec un autre utilisateur (par email - legacy)
  Future<SharedNote?> shareNote(Note note, String recipientEmail) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Vous devez être connecté pour partager une note');
    }

    // Chercher l'utilisateur destinataire par email
    final recipientQuery = await _usersCollection
        .where('email', isEqualTo: recipientEmail.toLowerCase().trim())
        .limit(1)
        .get();

    String recipientId;
    String recipientName;
    if (recipientQuery.docs.isEmpty) {
      recipientId = recipientEmail.toLowerCase().trim();
      recipientName = recipientEmail.toLowerCase().trim();
    } else {
      final doc = recipientQuery.docs.first;
      recipientId = doc.id;
      recipientName = (doc.data() as Map<String, dynamic>)['displayName'] ?? recipientEmail.toLowerCase().trim();
    }

    // Encoder les images en Base64
    final imagesBase64 = await ImageBase64Service.instance
        .encodeMultipleImages(note.imagePaths);

    // Créer la note partagée
    final sharedNoteId = _sharedNotesCollection.doc().id;
    final sharedNote = SharedNote(
      id: sharedNoteId,
      noteId: note.id,
      senderId: currentUser.uid,
      senderEmail: currentUser.email ?? '',
      senderName: currentUser.displayName ?? 'Utilisateur',
      recipientId: recipientId,
      recipientEmail: recipientEmail.toLowerCase().trim(),
      recipientName: recipientName,
      title: note.title,
      content: note.content,
      formattedContent: note.formattedContent,
      imagesBase64: imagesBase64,
      color: note.color.value,
      sharedAt: DateTime.now(),
      reactions: [],
      isRead: false,
    );

    await _sharedNotesCollection.doc(sharedNoteId).set(sharedNote.toJson());

    // Émettre une notification si l'utilisateur existe
    if (recipientId != recipientEmail) {
      await _notify(
        recipientId: recipientId,
        type: NotificationType.share,
        sharedNoteId: sharedNoteId,
        title: 'Nouvelle story reçue',
        body: '${currentUser.displayName ?? "Quelqu'un"} vous a partagé une story : ${note.title}',
      );
    }

    return sharedNote;
  }

  // ============================================================
  // RÉCUPÉRATION DES NOTES
  // ============================================================

  /// Récupère les notes partagées reçues par l'utilisateur actuel
  Future<List<SharedNote>> getReceivedNotes() async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];

    try {
      // On récupère tout sans orderBy pour éviter d'imposer des index composites Firebase
      final byIdQuery = await _sharedNotesCollection
          .where('recipientId', isEqualTo: currentUser.uid)
          .get();

      final byEmailQuery = await _sharedNotesCollection
          .where('recipientEmail', isEqualTo: currentUser.email?.toLowerCase())
          .get();

      final allDocs = <String, QueryDocumentSnapshot>{};
      for (final doc in byIdQuery.docs) {
        allDocs[doc.id] = doc;
      }
      for (final doc in byEmailQuery.docs) {
        allDocs[doc.id] = doc;
      }

      final notes = allDocs.values
          .map((doc) => SharedNote.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Tri local (plus robuste)
      notes.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      return notes;
    } catch (e) {
      debugPrint('Erreur récupération notes reçues: $e');
      rethrow; // Laisser l'UI attraper l'erreur
    }
  }

  /// Récupère les notes partagées envoyées par l'utilisateur actuel
  Future<List<SharedNote>> getSentNotes() async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return [];

    try {
      final query = await _sharedNotesCollection
          .where('senderId', isEqualTo: currentUser.uid)
          .get();

      final notes = query.docs
          .map((doc) => SharedNote.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Tri local
      notes.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      return notes;
    } catch (e) {
      debugPrint('Erreur récupération notes envoyées: $e');
      rethrow;
    }
  }

  /// Stream des notes reçues (temps réel)
  Stream<List<SharedNote>> watchReceivedNotes() {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _sharedNotesCollection
        .where('recipientEmail', isEqualTo: currentUser.email?.toLowerCase())
        .snapshots()
        .map((snapshot) {
      final notes = snapshot.docs
          .map((doc) => SharedNote.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      notes.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      return notes;
    });
  }

  /// Stream des notes envoyées (temps réel)
  Stream<List<SharedNote>> watchSentNotes() {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return Stream.value([]);

    return _sharedNotesCollection
        .where('senderId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
      final notes = snapshot.docs
          .map((doc) => SharedNote.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      notes.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      return notes;
    });
  }

  /// Stream du nombre de notes non lues reçues
  Stream<int> watchUnreadReceivedNotesCount() {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return Stream.value(0);

    return _sharedNotesCollection
        .where('recipientEmail', isEqualTo: currentUser.email?.toLowerCase())
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final isRead = data['isRead'] ?? true; 
            if (!isRead) count++;
          }
          return count;
    });
  }

  /// Marque une note partagée comme lue
  Future<void> markAsRead(String sharedNoteId) async {
    try {
      await _sharedNotesCollection.doc(sharedNoteId).update({'isRead': true});
      debugPrint('Note $sharedNoteId marquée comme lue');
    } catch (e) {
      debugPrint('Erreur markAsRead: $e');
    }
  }

  // ============================================================
  // RÉACTIONS ET COMMENTAIRES
  // ============================================================

  /// Ajoute une réaction emoji à une note partagée
  Future<void> addReaction(String sharedNoteId, String emoji) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Vous devez être connecté pour réagir');
    }

    final senderName = await _getCurrentUserName();

    final reaction = Reaction.createEmoji(
      emoji: emoji,
      userId: currentUser.uid,
      userName: senderName,
    );

    await _sharedNotesCollection.doc(sharedNoteId).update({
      'reactions': FieldValue.arrayUnion([reaction.toJson()]),
    });

    // Chercher le destinataire (le possesseur de la note partagée ou l'autre personne)
    final sharedNote = await getSharedNote(sharedNoteId);
    if (sharedNote != null) {
      final recipientId = (sharedNote.senderId == currentUser.uid) 
          ? sharedNote.recipientId 
          : sharedNote.senderId;

      await _notify(
        recipientId: recipientId,
        type: NotificationType.reaction,
        sharedNoteId: sharedNoteId,
        title: 'Nouvelle reaction',
        body: '$senderName a réagi $emoji à votre story',
      );
    }
  }

  /// Ajoute un commentaire à une note partagée
  Future<void> addComment(String sharedNoteId, String commentText) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      throw Exception('Vous devez être connecté pour commenter');
    }

    final senderName = await _getCurrentUserName();

    final comment = Reaction.createComment(
      comment: commentText,
      userId: currentUser.uid,
      userName: senderName,
    );

    await _sharedNotesCollection.doc(sharedNoteId).update({
      'reactions': FieldValue.arrayUnion([comment.toJson()]),
    });

    // Chercher le destinataire
    final sharedNote = await getSharedNote(sharedNoteId);
    if (sharedNote != null) {
      final recipientId = (sharedNote.senderId == currentUser.uid) 
          ? sharedNote.recipientId 
          : sharedNote.senderId;

      await _notify(
        recipientId: recipientId,
        type: NotificationType.comment,
        sharedNoteId: sharedNoteId,
        title: 'Nouveau commentaire',
        body: '$senderName a commenté : $commentText',
      );
    }
  }

  /// Retire une réaction ou commentaire d'une note partagée
  Future<void> removeReaction(String sharedNoteId, Reaction reaction) async {
    await _sharedNotesCollection.doc(sharedNoteId).update({
      'reactions': FieldValue.arrayRemove([reaction.toJson()]),
    });
  }

  /// Toggle une réaction emoji (ajouter si absente, retirer si présente)
  Future<void> toggleReaction(SharedNote sharedNote, String emoji) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    final existingReaction = sharedNote.getUserReaction(currentUser.uid, emoji);
    
    if (existingReaction != null) {
      await removeReaction(sharedNote.id, existingReaction);
    } else {
      await addReaction(sharedNote.id, emoji);
    }
  }

  // ============================================================
  // UTILITAIRES
  // ============================================================

  /// Récupère une note partagée par son ID
  Future<SharedNote?> getSharedNote(String sharedNoteId) async {
    try {
      final doc = await _sharedNotesCollection.doc(sharedNoteId).get();
      if (!doc.exists) return null;
      return SharedNote.fromJson(doc.data() as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Erreur récupération note partagée: $e');
      return null;
    }
  }

  /// Stream d'une note partagée (temps réel pour voir les réactions)
  Stream<SharedNote?> watchSharedNote(String sharedNoteId) {
    return _sharedNotesCollection.doc(sharedNoteId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return SharedNote.fromJson(doc.data() as Map<String, dynamic>);
    });
  }

  /// Supprime une note partagée
  Future<void> deleteSharedNote(String sharedNoteId) async {
    await _sharedNotesCollection.doc(sharedNoteId).delete();
  }

  /// Vérifie si une note a déjà été partagée avec quelqu'un
  Future<bool> isAlreadyShared(String noteId, String recipientEmail) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return false;

    final query = await _sharedNotesCollection
        .where('noteId', isEqualTo: noteId)
        .where('senderId', isEqualTo: currentUser.uid)
        .where('recipientEmail', isEqualTo: recipientEmail.toLowerCase())
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // ============================================================
  // NOTIFICATIONS (INTERNE)
  // ============================================================

  /// Crée une notification dans Firestore
  Future<void> _notify({
    required String recipientId,
    required NotificationType type,
    String? noteId,
    String? sharedNoteId,
    required String title,
    required String body,
  }) async {
    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) return;

    final senderName = await _getCurrentUserName();

    final notification = AppNotification(
      id: FirebaseFirestore.instance.collection('notifications').doc().id,
      recipientId: recipientId,
      senderId: currentUser.uid,
      senderName: senderName,
      type: type,
      noteId: noteId,
      sharedNoteId: sharedNoteId,
      title: title,
      body: body,
      timestamp: DateTime.now(),
      isRead: false,
    );

    await RealtimeNotificationService.instance.sendNotification(notification);
  }

  /// Helper pour récupérer le nom le plus actualisé possible
  Future<String> _getCurrentUserName() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return 'Utilisateur';
    
    // 1. Essayer Auth (plus rapide)
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!;
    }
    
    // 2. Fallback Firestore
    try {
      final doc = await _usersCollection.doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['displayName'] ?? 'Utilisateur';
      }
    } catch (e) {
      debugPrint('Err _getCurrentUserName fallback: $e');
    }
    
    return 'Utilisateur';
  }
}
