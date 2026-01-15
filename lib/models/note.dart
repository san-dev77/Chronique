import 'package:flutter/material.dart';

class Note {
  String id;
  String title;
  String content;
  String? formattedContent; // JSON du contenu formaté (rich text)
  DateTime createdAt;
  DateTime modifiedAt;
  List<String> imagePaths;
  Color color;
  bool isFavorite;

  Note({
    required this.id,
    required this.title,
    required this.content,
    this.formattedContent,
    required this.createdAt,
    required this.modifiedAt,
    this.imagePaths = const [],
    this.color = Colors.white,
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'formattedContent': formattedContent,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'imagePaths': imagePaths,
      'color': color.value,
      'isFavorite': isFavorite,
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      formattedContent: json['formattedContent'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      color: Color(json['color'] ?? Colors.white.value),
      isFavorite: json['isFavorite'] ?? false,
    );
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? formattedContent,
    DateTime? createdAt,
    DateTime? modifiedAt,
    List<String>? imagePaths,
    Color? color,
    bool? isFavorite,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      formattedContent: formattedContent ?? this.formattedContent,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      imagePaths: imagePaths ?? this.imagePaths,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
