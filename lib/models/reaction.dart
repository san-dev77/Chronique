/// Modèle pour les réactions et commentaires sur les notes partagées
class Reaction {
  final String id;
  final String emoji;       // Émoji pour les réactions (vide si c'est un commentaire)
  final String? comment;    // Commentaire textuel (null si c'est juste une réaction)
  final String userId;
  final String userName;
  final DateTime createdAt;

  Reaction({
    required this.id,
    required this.emoji,
    this.comment,
    required this.userId,
    required this.userName,
    required this.createdAt,
  });

  /// Vérifie si c'est un commentaire (pas juste une réaction emoji)
  bool get isComment => comment != null && comment!.isNotEmpty;

  /// Vérifie si c'est une réaction emoji simple
  bool get isEmojiReaction => emoji.isNotEmpty && !isComment;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'emoji': emoji,
      'comment': comment,
      'userId': userId,
      'userName': userName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Reaction.fromJson(Map<String, dynamic> json) {
    return Reaction(
      id: json['id'] ?? '',
      emoji: json['emoji'] ?? '',
      comment: json['comment'],
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonyme',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }

  /// Émojis de réaction disponibles
  static const List<String> availableEmojis = ['❤️', '👍', '😮', '😂', '👏'];

  /// Crée une réaction emoji
  static Reaction createEmoji({
    required String emoji,
    required String userId,
    required String userName,
  }) {
    return Reaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      emoji: emoji,
      comment: null,
      userId: userId,
      userName: userName,
      createdAt: DateTime.now(),
    );
  }

  /// Crée un commentaire
  static Reaction createComment({
    required String comment,
    required String userId,
    required String userName,
  }) {
    return Reaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      emoji: '💬',
      comment: comment,
      userId: userId,
      userName: userName,
      createdAt: DateTime.now(),
    );
  }
}
