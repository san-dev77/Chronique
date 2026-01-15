import 'reaction.dart';

/// Modèle pour les notes partagées entre utilisateurs
class SharedNote {
  final String id;
  final String noteId;
  final String senderId;
  final String senderEmail;
  final String senderName;
  final String recipientId;
  final String recipientEmail;
  final String recipientName;
  final String title;
  final String content;
  final String? formattedContent;
  final List<String> imagesBase64;
  final int color;
  final DateTime sharedAt;
  final List<Reaction> reactions;
  final bool isRead;

  SharedNote({
    required this.id,
    required this.noteId,
    required this.senderId,
    required this.senderEmail,
    required this.senderName,
    required this.recipientId,
    required this.recipientEmail,
    required this.recipientName,
    required this.title,
    required this.content,
    this.formattedContent,
    this.imagesBase64 = const [],
    required this.color,
    required this.sharedAt,
    this.reactions = const [],
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'noteId': noteId,
      'senderId': senderId,
      'senderEmail': senderEmail,
      'senderName': senderName,
      'recipientId': recipientId,
      'recipientEmail': recipientEmail,
      'recipientName': recipientName,
      'title': title,
      'content': content,
      'formattedContent': formattedContent,
      'imagesBase64': imagesBase64,
      'color': color,
      'sharedAt': sharedAt.toIso8601String(),
      'reactions': reactions.map((r) => r.toJson()).toList(),
      'isRead': isRead,
    };
  }

  factory SharedNote.fromJson(Map<String, dynamic> json) {
    return SharedNote(
      id: json['id'] ?? '',
      noteId: json['noteId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderEmail: json['senderEmail'] ?? '',
      senderName: json['senderName'] ?? 'Anonyme',
      recipientId: json['recipientId'] ?? '',
      recipientEmail: json['recipientEmail'] ?? '',
      recipientName: json['recipientName'] ?? json['recipientEmail'] ?? 'Utilisateur',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      formattedContent: json['formattedContent'],
      imagesBase64: List<String>.from(json['imagesBase64'] ?? []),
      color: json['color'] ?? 0xFFFFFFFF,
      sharedAt: json['sharedAt'] != null
          ? DateTime.parse(json['sharedAt'])
          : DateTime.now(),
      reactions: (json['reactions'] as List<dynamic>?)
              ?.map((r) => Reaction.fromJson(Map<String, dynamic>.from(r)))
              .toList() ??
          [],
      isRead: json['isRead'] ?? true, // Default to true for existing notes
    );
  }

  /// Vérifie si l'utilisateur actuel a déjà réagi avec cet emoji
  bool hasReacted(String userId, String emoji) {
    return reactions.any((r) => r.userId == userId && r.emoji == emoji);
  }

  /// Récupère la réaction de l'utilisateur pour un emoji donné
  Reaction? getUserReaction(String userId, String emoji) {
    try {
      return reactions.firstWhere((r) => r.userId == userId && r.emoji == emoji);
    } catch (e) {
      return null;
    }
  }

  /// Compte le nombre de réactions par emoji
  Map<String, int> get reactionCounts {
    final counts = <String, int>{};
    for (final reaction in reactions) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    return counts;
  }

  SharedNote copyWith({
    String? id,
    String? noteId,
    String? senderId,
    String? senderEmail,
    String? senderName,
    String? recipientId,
    String? recipientEmail,
    String? recipientName,
    String? title,
    String? content,
    List<String>? imagesBase64,
    int? color,
    DateTime? sharedAt,
    List<Reaction>? reactions,
    bool? isRead,
  }) {
    return SharedNote(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      senderId: senderId ?? this.senderId,
      senderEmail: senderEmail ?? this.senderEmail,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      recipientName: recipientName ?? this.recipientName,
      title: title ?? this.title,
      content: content ?? this.content,
      formattedContent: formattedContent ?? this.formattedContent,
      imagesBase64: imagesBase64 ?? this.imagesBase64,
      color: color ?? this.color,
      sharedAt: sharedAt ?? this.sharedAt,
      reactions: reactions ?? this.reactions,
      isRead: isRead ?? this.isRead,
    );
  }
}
