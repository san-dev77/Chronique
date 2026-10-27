import 'dart:math';
import '../models/note.dart';
import 'note_service.dart';

class MemoryService {
  static final MemoryService _instance = MemoryService._internal();
  factory MemoryService() => _instance;
  MemoryService._internal();

  static MemoryService get instance => _instance;

  /// Obtient une note aléatoire d'il y a au moins 7 jours pour les souvenirs
  Note? getRandomMemory() {
    final allNotes = NoteService.instance.getAllNotes();
    final now = DateTime.now();
    
    // Filtrer les notes d'au moins 7 jours
    final oldNotes = allNotes.where((note) {
      final daysDiff = now.difference(note.createdAt).inDays;
      return daysDiff >= 7;
    }).toList();

    if (oldNotes.isEmpty) return null;

    // Prioriser les notes avec images ou citations
    final priorityNotes = oldNotes.where((note) {
      return note.imagePaths.isNotEmpty || 
             (note.quote != null && note.quote!.isNotEmpty) ||
             note.isFavorite;
    }).toList();

    final notesToChooseFrom = priorityNotes.isNotEmpty ? priorityNotes : oldNotes;
    
    if (notesToChooseFrom.isEmpty) return null;
    
    final random = Random();
    return notesToChooseFrom[random.nextInt(notesToChooseFrom.length)];
  }

  /// Obtient plusieurs souvenirs pour un diaporama
  List<Note> getMemorySlideshow({int count = 5}) {
    final allNotes = NoteService.instance.getAllNotes();
    final now = DateTime.now();
    
    // Filtrer les notes d'au moins 3 jours pour avoir plus de choix
    final oldNotes = allNotes.where((note) {
      final daysDiff = now.difference(note.createdAt).inDays;
      return daysDiff >= 3;
    }).toList();

    if (oldNotes.isEmpty) return [];

    // Trier par priorité (favoris, avec images, avec citations)
    oldNotes.sort((a, b) {
      int scoreA = _getMemoryScore(a);
      int scoreB = _getMemoryScore(b);
      return scoreB.compareTo(scoreA);
    });

    // Prendre les meilleures notes mais avec un peu d'aléatoire
    final selectedNotes = <Note>[];
    final random = Random();
    
    // Prendre les top notes avec un peu d'aléatoire
    final topNotes = oldNotes.take(count * 2).toList();
    
    while (selectedNotes.length < count && topNotes.isNotEmpty) {
      final index = random.nextInt(topNotes.length);
      selectedNotes.add(topNotes.removeAt(index));
    }

    return selectedNotes;
  }

  int _getMemoryScore(Note note) {
    int score = 0;
    
    // Points pour les favoris
    if (note.isFavorite) score += 10;
    
    // Points pour les images
    if (note.imagePaths.isNotEmpty) score += 8;
    
    // Points pour les citations
    if (note.quote != null && note.quote!.isNotEmpty) score += 6;
    
    // Points pour l'ancienneté (plus c'est vieux, plus c'est intéressant)
    final daysDiff = DateTime.now().difference(note.createdAt).inDays;
    if (daysDiff > 30) score += 5;
    if (daysDiff > 90) score += 3;
    if (daysDiff > 365) score += 5;
    
    // Points pour la longueur du contenu
    if (note.content.length > 100) score += 2;
    if (note.title.isNotEmpty) score += 1;
    
    return score;
  }

  /// Vérifie s'il faut afficher une notification de souvenir
  bool shouldShowMemoryNotification() {
    final memory = getRandomMemory();
    if (memory == null) return false;
    
    // Logique pour déterminer quand afficher (par exemple, pas plus d'une fois par jour)
    final now = DateTime.now();
    final lastShown = _getLastMemoryNotificationTime();
    
    if (lastShown == null) return true;
    
    final hoursSinceLastShown = now.difference(lastShown).inHours;
    return hoursSinceLastShown >= 6; // Au moins 6h entre les notifications
  }

  DateTime? _getLastMemoryNotificationTime() {
    // TODO: Implémenter la persistance avec SharedPreferences
    // Pour l'instant, retourner null pour toujours permettre
    return null;
  }

  void _setLastMemoryNotificationTime(DateTime time) {
    // TODO: Implémenter la persistance avec SharedPreferences
  }

  /// Messages d'incitation pour les souvenirs
  List<String> get memoryPrompts => [
    "💭 Un souvenir vous attend...",
    "📖 Redécouvrez vos anciennes chroniques",
    "✨ Voyage dans vos souvenirs",
    "🌟 Une pépite de votre passé",
    "💫 Retour vers vos pensées d'antan",
    "🎭 Vos émotions d'hier",
    "🌙 Nostalgie de vos écrits",
    "🎨 Vos créations oubliées",
  ];

  String getRandomMemoryPrompt() {
    final random = Random();
    return memoryPrompts[random.nextInt(memoryPrompts.length)];
  }
}