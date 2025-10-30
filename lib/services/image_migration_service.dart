import 'note_service.dart';
import 'image_storage_service.dart';

/// Service pour migrer les images existantes depuis le cache vers le stockage permanent
class ImageMigrationService {
  static ImageMigrationService? _instance;

  ImageMigrationService._();

  static ImageMigrationService get instance {
    _instance ??= ImageMigrationService._();
    return _instance!;
  }

  /// Répare toutes les images cassées en les migrant vers le stockage permanent
  /// 
  /// Retourne un rapport de migration
  Future<MigrationReport> repairAllImages() async {
    final report = MigrationReport();
    
    try {
      // Récupérer toutes les notes
      final notes = NoteService.instance.getAllNotes();
      report.totalNotes = notes.length;

      for (final note in notes) {
        bool noteModified = false;
        final repairedPaths = <String>[];

        for (final imagePath in note.imagePaths) {
          report.totalImages++;

          // Vérifier si l'image existe
          final exists = await ImageStorageService.instance.imageExists(imagePath);

          if (exists) {
            // Image OK
            if (imagePath.contains('/cache/')) {
              // Dans le cache mais existe encore : migrer
              try {
                final newPath = await ImageStorageService.instance
                    .saveImagePermanently(imagePath);
                repairedPaths.add(newPath);
                report.migratedImages++;
                noteModified = true;
              } catch (e) {
                // Impossible de migrer, garder l'ancien chemin
                repairedPaths.add(imagePath);
                report.failedImages++;
              }
            } else {
              // Déjà dans le stockage permanent
              repairedPaths.add(imagePath);
              report.validImages++;
            }
          } else {
            // Image cassée (n'existe plus)
            report.brokenImages++;
            // Ne pas ajouter à repairedPaths (suppression de la référence)
          }
        }

        // Si la note a été modifiée, sauvegarder
        if (noteModified || repairedPaths.length != note.imagePaths.length) {
          final updatedNote = note.copyWith(imagePaths: repairedPaths);
          await NoteService.instance.saveNote(updatedNote);
          report.notesUpdated++;
        }
      }

      report.success = true;
    } catch (e) {
      report.success = false;
      report.errorMessage = e.toString();
    }

    return report;
  }

  /// Nettoie les images orphelines (non référencées)
  Future<int> cleanupOrphanImages() async {
    try {
      // Récupérer toutes les notes
      final notes = NoteService.instance.getAllNotes();
      
      // Collecter tous les chemins d'images utilisés
      final usedImagePaths = <String>{};
      for (final note in notes) {
        usedImagePaths.addAll(note.imagePaths);
      }

      // Nettoyer les orphelines
      return await ImageStorageService.instance
          .cleanupOrphanImages(usedImagePaths.toList());
    } catch (e) {
      print('Erreur nettoyage orphelines: $e');
      return 0;
    }
  }

  /// Analyse l'état des images sans modifier
  Future<ImageAnalysisReport> analyzeImages() async {
    final report = ImageAnalysisReport();

    try {
      final notes = NoteService.instance.getAllNotes();
      report.totalNotes = notes.length;

      final allImagePaths = <String>{};

      for (final note in notes) {
        for (final imagePath in note.imagePaths) {
          allImagePaths.add(imagePath);
          report.totalImages++;

          final exists = await ImageStorageService.instance.imageExists(imagePath);

          if (exists) {
            if (imagePath.contains('/cache/')) {
              report.inCacheCount++;
            } else {
              report.inPermanentStorageCount++;
            }
          } else {
            report.brokenCount++;
          }
        }
      }

      // Calculer la taille totale
      report.totalSize = await ImageStorageService.instance.getTotalImagesSize();
      
      // Compter les images dans le stockage
      report.storedImagesCount = await ImageStorageService.instance.countStoredImages();

    } catch (e) {
      report.errorMessage = e.toString();
    }

    return report;
  }
}

/// Rapport de migration des images
class MigrationReport {
  bool success = false;
  int totalNotes = 0;
  int totalImages = 0;
  int validImages = 0;      // Images déjà dans le bon dossier
  int migratedImages = 0;   // Images migrées depuis le cache
  int brokenImages = 0;     // Images cassées (supprimées)
  int failedImages = 0;     // Images qu'on n'a pas pu migrer
  int notesUpdated = 0;
  String? errorMessage;

  String getSummary() {
    if (!success) {
      return 'Erreur : ${errorMessage ?? "Inconnue"}';
    }

    final parts = <String>[];
    
    parts.add('$totalNotes note(s) analysée(s)');
    parts.add('$totalImages image(s) au total');
    
    if (migratedImages > 0) {
      parts.add('✅ $migratedImages migrée(s)');
    }
    
    if (validImages > 0) {
      parts.add('✓ $validImages déjà OK');
    }
    
    if (brokenImages > 0) {
      parts.add('❌ $brokenImages cassée(s) supprimée(s)');
    }
    
    if (failedImages > 0) {
      parts.add('⚠️ $failedImages échec(s)');
    }

    return parts.join('\n');
  }
}

/// Rapport d'analyse des images (sans modification)
class ImageAnalysisReport {
  int totalNotes = 0;
  int totalImages = 0;
  int inCacheCount = 0;           // Images dans /cache/
  int inPermanentStorageCount = 0; // Images dans stockage permanent
  int brokenCount = 0;             // Images cassées
  int storedImagesCount = 0;       // Nombre de fichiers dans le dossier
  int totalSize = 0;               // Taille totale en bytes
  String? errorMessage;

  String getSummary() {
    if (errorMessage != null) {
      return 'Erreur : $errorMessage';
    }

    final parts = <String>[];
    
    parts.add('📊 Analyse');
    parts.add('$totalNotes note(s) • $totalImages image(s)');
    parts.add('');
    
    if (inPermanentStorageCount > 0) {
      parts.add('✅ $inPermanentStorageCount sécurisée(s)');
    }
    
    if (inCacheCount > 0) {
      parts.add('⚠️ $inCacheCount dans cache (à risque)');
    }
    
    if (brokenCount > 0) {
      parts.add('❌ $brokenCount cassée(s)');
    }
    
    parts.add('');
    parts.add('💾 Stockage : ${ImageStorageService.formatBytes(totalSize)}');

    return parts.join('\n');
  }

  bool hasIssues() {
    return inCacheCount > 0 || brokenCount > 0;
  }
}

