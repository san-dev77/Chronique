class Spark {
  final String id;
  String title;
  String? description;
  String? imagePath;
  final DateTime createdAt;
  DateTime modifiedAt;

  Spark({
    required this.id,
    required this.title,
    this.description,
    this.imagePath,
    required this.createdAt,
    required this.modifiedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  factory Spark.fromJson(Map<String, dynamic> json) {
    return Spark(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      imagePath: json['imagePath'],
      createdAt: DateTime.parse(json['createdAt']),
      modifiedAt: DateTime.parse(json['modifiedAt']),
    );
  }

  Spark copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Spark(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }
}
