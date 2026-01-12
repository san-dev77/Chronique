import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_notification.dart';
import 'auth_service.dart';
import 'memory_notification_service.dart';

/// Service pour écouter les notifications Firestore en temps réel
class RealtimeNotificationService {
  static final RealtimeNotificationService instance = RealtimeNotificationService._();
  RealtimeNotificationService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;

  CollectionReference get _notificationsCollection => _firestore.collection('notifications');

  /// Commence à écouter les notifications pour l'utilisateur actuel
  void startListening() {
    final user = AuthService.instance.currentUser;
    if (user == null) return;

    // Arrêter l'ancienne subscription si elle existe
    stopListening();

    _subscription = _notificationsCollection
        .where('recipientId', isEqualTo: user.uid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final notification = AppNotification.fromFirestore(change.doc);
          _handleNewNotification(notification);
        }
      }
    });
  }

  /// Arrête l'écoute
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// Traite une nouvelle notification reçue
  Future<void> _handleNewNotification(AppNotification notif) async {
    // Éviter l'auto-notification (normalement géré par les queries mais on ne sait jamais)
    if (notif.senderId == AuthService.instance.userId) return;

    // Afficher la notification locale
    await MemoryNotificationService.instance.showLocalNotification(
      id: notif.id.hashCode,
      title: notif.title,
      body: notif.body,
      payload: notif.sharedNoteId ?? notif.noteId,
    );

    // Marquer comme 'read' dans Firestore pour ne pas la recevoir à nouveau
    await markAsRead(notif.id);
  }

  /// Marque une notification comme lue
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Erreur markAsRead: $e');
    }
  }

  /// Crée une nouvelle notification dans Firestore (appelé par SharingService)
  Future<void> sendNotification(AppNotification notification) async {
    try {
      await _notificationsCollection.doc(notification.id).set(notification.toJson());
    } catch (e) {
      debugPrint('Erreur sendNotification: $e');
    }
  }
}
