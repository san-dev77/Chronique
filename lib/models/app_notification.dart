import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  share,
  reaction,
  comment
}

class AppNotification {
  final String id;
  final String recipientId;
  final String senderId;
  final String senderName;
  final NotificationType type;
  final String? noteId;
  final String? sharedNoteId;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.recipientId,
    required this.senderId,
    required this.senderName,
    required this.type,
    this.noteId,
    this.sharedNoteId,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipientId': recipientId,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'noteId': noteId,
      'sharedNoteId': sharedNoteId,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      recipientId: json['recipientId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Anonyme',
      type: NotificationType.values.byName(json['type'] ?? 'share'),
      noteId: json['noteId'],
      sharedNoteId: json['sharedNoteId'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    return AppNotification.fromJson(doc.data() as Map<String, dynamic>);
  }
}
