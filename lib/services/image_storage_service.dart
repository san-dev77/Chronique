import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Service pour gérer le stockage permanent des images
/// 
/// Problème résolu : les images dans /cache/ sont supprimées automatiquement
/// Solution : copier dans le dossier permanent de l'app
class ImageStorageService {
  static ImageStorageService? _instance;
  static Directory? _imagesDirectory;

  ImageStorageService._();

  static ImageStorageService get instance {
    _instance ??= ImageStorageService._();
    return _instance!;
  }

  /// Initialise le dossier de stockage permanent des images
  Future<void> initialize() async {
    if (_imagesDirectory == null) {
      final appDir = await getApplicationDocumentsDirectory();
      _imagesDirectory = Directory('${appDir.path}/note_images');
      
      if (!await _imagesDirectory!.exists()) {
        await _imagesDirectory!.create(recursive: true);
      }
    }
  }

  /// Copie une image depuis le cache temporaire vers le stockage permanent
  /// 
  /// [sourcePath] : chemin de l'image temporaire (ex: /cache/scaled_xxx.jpg)
  /// Retourne : nouveau chemin permanent
  Future<String> saveImagePermanently(String sourcePath) async {
    await initialize();

    final sourceFile = File(sourcePath);
    
    // Vérifier que le fichier source existe
    if (!await sourceFile.exists()) {
      throw Exception('Image source introuvable: $sourcePath');
    }

    // Générer un nom unique avec timestamp
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourcePath);
    final fileName = 'note_image_$timestamp$extension';
    
    final destinationPath = '${_imagesDirectory!.path}/$fileName';
    
    // Copier le fichier
    await sourceFile.copy(destinationPath);
    
    return destinationPath;
  }

  /// Copie plusieurs images
  Future<List<String>> saveImagesPermanently(List<String> sourcePaths) async {
    final permanentPaths = <String>[];
    
    for (final sourcePath in sourcePaths) {
      try {
        final permanentPath = await saveImagePermanently(sourcePath);
        permanentPaths.add(permanentPath);
      } catch (e) {
        print('Erreur copie image $sourcePath: $e');
        // Continuer avec les autres images
      }
    }
    
    return permanentPaths;
  }

  /// Sauvegarde une image à partir de ses bytes (utile pour le Cloud Sync)
  Future<String> saveImageFromBytes(Uint8List bytes, String extension) async {
    await initialize();

    // Générer un nom unique
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'note_image_$timestamp.$extension';
    final destinationPath = '${_imagesDirectory!.path}/$fileName';
    
    final file = File(destinationPath);
    await file.writeAsBytes(bytes);
    
    return destinationPath;
  }

  /// Vérifie si une image existe et est accessible
  Future<bool> imageExists(String imagePath) async {
    try {
      final file = File(imagePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Vérifie plusieurs images et retourne les chemins valides
  Future<List<String>> filterValidImages(List<String> imagePaths) async {
    final validPaths = <String>[];
    
    for (final imagePath in imagePaths) {
      if (await imageExists(imagePath)) {
        validPaths.add(imagePath);
      }
    }
    
    return validPaths;
  }

  /// Tente de réparer une image cassée en la copiant si elle est dans /cache/
  /// Retourne : nouveau chemin si réparé, null si impossible
  Future<String?> tryRepairImage(String brokenPath) async {
    try {
      // Si l'image existe déjà et n'est pas dans le cache, pas besoin de réparer
      if (await imageExists(brokenPath) && !brokenPath.contains('/cache/')) {
        return brokenPath;
      }

      // Si dans le cache et existe encore, copier
      if (await imageExists(brokenPath) && brokenPath.contains('/cache/')) {
        return await saveImagePermanently(brokenPath);
      }

      return null;
    } catch (e) {
      print('Impossible de réparer $brokenPath: $e');
      return null;
    }
  }

  /// Supprime une image du stockage permanent
  Future<void> deleteImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Erreur suppression image $imagePath: $e');
    }
  }

  /// Supprime plusieurs images
  Future<void> deleteImages(List<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      await deleteImage(imagePath);
    }
  }

  /// Nettoie les images orphelines (non référencées par aucune note)
  Future<int> cleanupOrphanImages(List<String> allUsedImagePaths) async {
    await initialize();

    int deletedCount = 0;

    try {
      final allFiles = await _imagesDirectory!.list().toList();
      
      for (final fileEntity in allFiles) {
        if (fileEntity is File) {
          final filePath = fileEntity.path;
          
          // Si l'image n'est référencée par aucune note
          if (!allUsedImagePaths.contains(filePath)) {
            await fileEntity.delete();
            deletedCount++;
          }
        }
      }
    } catch (e) {
      print('Erreur nettoyage images orphelines: $e');
    }

    return deletedCount;
  }

  /// Récupère la taille totale des images stockées (en bytes)
  Future<int> getTotalImagesSize() async {
    await initialize();

    int totalSize = 0;

    try {
      final allFiles = await _imagesDirectory!.list().toList();
      
      for (final fileEntity in allFiles) {
        if (fileEntity is File) {
          final stat = await fileEntity.stat();
          totalSize += stat.size;
        }
      }
    } catch (e) {
      print('Erreur calcul taille images: $e');
    }

    return totalSize;
  }

  /// Formate une taille en bytes en format lisible
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Obtient le chemin du dossier des images
  Future<String> getImagesDirectoryPath() async {
    await initialize();
    return _imagesDirectory!.path;
  }

  /// Compte le nombre d'images stockées
  Future<int> countStoredImages() async {
    await initialize();

    try {
      final allFiles = await _imagesDirectory!.list().toList();
      return allFiles.where((f) => f is File).length;
    } catch (e) {
      print('Erreur comptage images: $e');
      return 0;
    }
  }
}

