import 'package:flutter/material.dart';

class Note {
  String id;
  String title;
  String content;
  String? formattedContent; // JSON du contenu formaté (rich text)
  String? quote; // Citation pour la chronique
  DateTime createdAt;
  DateTime modifiedAt;
  List<String> imagePaths;

  /// Empreintes des images telles qu'elles existent dans le cloud.
  ///
  /// Les chemins locaux ne veulent rien dire d'un appareil a l'autre ; une
  /// empreinte, si. Elle permet de savoir sans rien telecharger si cet
  /// appareil possede deja la photo, et d'eviter de renvoyer deux fois le
  /// meme megaoctet.
  List<String> imageHashes;

  Color color;
  bool isFavorite;

  /// Citation epinglee : celle qui a marque, qu'on veut retrouver en tete.
  ///
  /// Distincte du favori, qui vaut pour la chronique entiere. Une phrase
  /// peut rester en memoire sans que le texte autour le merite.
  bool isPinned;

  String? mood;      // Clé de l'aura (ex: 'serene', 'dark', 'angry'...)
  int? moodColor;    // Couleur personnalisée du halo (override de la couleur par défaut)

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.formattedContent,
    this.quote,
    required this.createdAt,
    required this.modifiedAt,
    this.imagePaths = const [],
    this.imageHashes = const [],
    this.color = Colors.white,
    this.isFavorite = false,
    this.isPinned = false,
    this.mood,
    this.moodColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'formattedContent': formattedContent,
      'quote': quote,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'imagePaths': imagePaths,
      'imageHashes': imageHashes,
      'color': color.value,
      'isFavorite': isFavorite,
      'isPinned': isPinned,
      'mood': mood,
      'moodColor': moodColor,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      formattedContent: json['formattedContent'],
      quote: json['quote'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      imageHashes: List<String>.from(json['imageHashes'] ?? []),
      color: Color(json['color'] ?? Colors.white.value),
      isFavorite: json['isFavorite'] ?? false,
      isPinned: json['isPinned'] ?? false,
      mood: json['mood'],
      moodColor: json['moodColor'],
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? formattedContent,
    String? quote,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<String>? imagePaths,
    List<String>? imageHashes,
    Color? color,
    bool? isFavorite,
    bool? isPinned,
    String? mood,
    int? moodColor,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      formattedContent: formattedContent ?? this.formattedContent,
      quote: quote ?? this.quote,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      imagePaths: imagePaths ?? this.imagePaths,
      imageHashes: imageHashes ?? this.imageHashes,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
      isPinned: isPinned ?? this.isPinned,
      mood: mood ?? this.mood,
      moodColor: moodColor ?? this.moodColor,
    );
  }
}
