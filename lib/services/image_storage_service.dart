import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import '../utils/app_paths.dart';

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
      final appDir = await AppPaths.storageRoot();
      _imagesDirectory = Directory('${appDir.path}/note_images');
      
      if (!await _imagesDirectory!.exists()) {
        await _imagesDirectory!.create(recursive: true);
      }
    }
  }

  /// Ce chemin est-il deja dans le stockage permanent ?
  ///
  /// Sert a ne pas recopier une image qui s'y trouve deja : chaque copie
  /// inutile est un doublon qui occupe la place sur le telephone et une
  /// photo de plus a envoyer au cloud.
  bool isManaged(String filePath) {
    final dir = _imagesDirectory;
    if (dir == null) return false;
    return path.equals(path.dirname(filePath), dir.path);
  }

  /// Copie une image depuis le cache temporaire vers le stockage permanent
  ///
  /// [sourcePath] : chemin de l'image temporaire (ex: /cache/scaled_xxx.jpg)
  /// Retourne : nouveau chemin permanent
  Future<String> saveImagePermanently(String sourcePath) async {
    await initialize();

    // Deja a l'abri : recopier ne ferait qu'un doublon de plus. Le
    // recadrage ecrit desormais directement ici, et il traverse ce chemin
    // comme les autres.
    if (isManaged(sourcePath)) return sourcePath;

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

  // ====================================================== images du cloud

  /// Empreinte courte d'un contenu binaire.
  static String fingerprint(Uint8List bytes) =>
      sha1.convert(bytes).toString().substring(0, 20);

  /// Enregistre une image venue du cloud sous un nom derive de son contenu.
  ///
  /// C'est le correctif central : l'ancienne version ecrivait un fichier
  /// horodate a chaque synchronisation, si bien que les memes images etaient
  /// recopiees encore et encore. Le dossier avait atteint 27 000 fichiers pour
  /// 3,6 Go. Avec un nom derive du contenu, une image deja presente est
  /// simplement reutilisee.
  Future<String> saveCloudImage(Uint8List bytes, String extension) async {
    await initialize();
    final name = 'cloud_${fingerprint(bytes)}.$extension';
    final destination = '${_imagesDirectory!.path}/$name';

    final file = File(destination);
    if (await file.exists()) return destination;

    await file.writeAsBytes(bytes);
    return destination;
  }

  /// Chemin local d'une image du cloud, si on l'a deja.
  Future<String?> findCloudImage(String hash) async {
    await initialize();
    for (final ext in const ['jpg', 'png', 'webp']) {
      final candidate = File('${_imagesDirectory!.path}/cloud_$hash.$ext');
      if (await candidate.exists()) return candidate.path;
    }
    return null;
  }

  /// Donne a une image locale le nom derive de son empreinte dans le cloud.
  ///
  /// Quand une note est deja synchronisee et que le nombre de photos
  /// correspond, les fichiers presents sont les bons : seul leur nom date
  /// d'avant. Les recopier sous le nom attendu evite de retelecharger ce que
  /// l'appareil possede deja.
  Future<String?> adoptAs(String localPath, String hash) async {
    await initialize();
    final source = File(localPath);
    if (!await source.exists()) return null;

    // Quatre octets suffisent a reconnaitre le format : inutile de relire
    // toute la photo.
    String ext;
    final handle = await source.open();
    try {
      ext = extensionOf(await handle.read(4));
    } finally {
      await handle.close();
    }

    final target = '${_imagesDirectory!.path}/cloud_$hash.$ext';
    final file = File(target);
    // Une copie, pas un deplacement : une autre note peut encore pointer sur
    // l'ancien chemin. Le nettoyage des orphelins s'en occupera.
    if (!await file.exists()) await source.copy(target);
    return target;
  }

  // ================================================= preparation a l'envoi

  /// Reduit une image pour qu'elle tienne dans un document Firestore.
  ///
  /// Un document est plafonne a 1 Mio, et le base64 gonfle de 33 % : il faut
  /// donc viser environ 700 Kio de binaire. image_picker ignore `maxWidth` et
  /// `imageQuality` sur Windows, ou une photo d'appareil arrive donc intacte —
  /// 8 Mo qui ne passeraient jamais.
  /// [budget] se partage entre les photos d'une meme note : trois images a
  /// 700 Kio feraient deux megaoctets pour une seule chronique.
  static Future<Uint8List> compressForCloud(
    Uint8List bytes, {
    int budget = 700 * 1024,
  }) async {
    if (bytes.length <= budget) return bytes;
    return compute(_resizeInIsolate, (bytes: bytes, budget: budget));
  }

  /// Budget binaire a accorder a chaque photo d'une note.
  ///
  /// Une chronique reste autour du megaoctet, quel que soit le nombre de
  /// photos : l'important est que le quota gratuit tienne dans l'annee.
  static int budgetFor(int imageCount) {
    if (imageCount <= 1) return 700 * 1024;
    if (imageCount == 2) return 440 * 1024;
    return 300 * 1024;
  }

  /// Format reel d'un binaire, lu dans ses premiers octets.
  ///
  /// Se fier a l'extension du fichier ne suffit pas : une image recompressee
  /// en JPEG garderait un nom en .png, et le decodeur s'y perdrait.
  static String extensionOf(Uint8List bytes) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0x89 && bytes[1] == 0x50) return 'png';
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
      if (bytes[0] == 0x52 && bytes[1] == 0x49) return 'webp';
    }
    return 'jpg';
  }

  /// Nettoie les images qu'aucune note ne reference plus.
  ///
  /// Renvoie le nombre de fichiers supprimes et les octets liberes.
  /// [dryRun] compte sans rien effacer : de quoi annoncer le menage avant
  /// de le faire. Une suppression de donnees se montre avant de s'executer.
  Future<({int files, int bytes})> removeOrphans(
    Set<String> referencedPaths, {
    bool dryRun = false,
  }) async {
    await initialize();

    // On compare les noms de fichiers, pas les chemins : le dossier de
    // l'application change d'un lancement a l'autre sur certains systemes,
    // et un chemin absolu enregistre hier peut ne plus correspondre.
    final referenced = referencedPaths
        .map((p) => path.basename(p).toLowerCase())
        .toSet();

    var count = 0;
    var freed = 0;
    await for (final entity in _imagesDirectory!.list()) {
      if (entity is! File) continue;
      final name = path.basename(entity.path).toLowerCase();
      if (referenced.contains(name)) continue;
      try {
        final size = await entity.length();
        if (!dryRun) await entity.delete();
        count++;
        freed += size;
      } catch (_) {
        // Fichier verrouille ou deja parti : on passe au suivant.
      }
    }
    return (files: count, bytes: freed);
  }

  /// Poids total du dossier d'images.
  Future<({int files, int bytes})> usage() async {
    await initialize();
    var count = 0;
    var total = 0;
    await for (final entity in _imagesDirectory!.list()) {
      if (entity is! File) continue;
      count++;
      total += await entity.length();
    }
    return (files: count, bytes: total);
  }
}

/// Redimensionnement execute hors du thread d'interface : decoder puis
/// reencoder une photo bloque plusieurs centaines de millisecondes.
Uint8List _resizeInIsolate(({Uint8List bytes, int budget}) job) {
  final bytes = job.bytes;
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    // 1600 px de cote suffisent largement pour une chronique.
    final resized = decoded.width > 1600 || decoded.height > 1600
        ? img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? 1600 : null,
            height: decoded.height > decoded.width ? 1600 : null,
            interpolation: img.Interpolation.average,
          )
        : decoded;

    // On baisse la qualite par paliers jusqu'a tenir dans le budget.
    for (final quality in const [85, 72, 60, 48]) {
      final encoded = img.encodeJpg(resized, quality: quality);
      if (encoded.length <= job.budget) return encoded;
    }
    return img.encodeJpg(resized, quality: 40);
  } catch (_) {
    return bytes;
  }
}
