import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Service pour encoder/décoder les images en Base64
/// Permet de transférer les images via Firestore sans stockage externe
class ImageBase64Service {
  static ImageBase64Service? _instance;

  ImageBase64Service._();

  static ImageBase64Service get instance {
    _instance ??= ImageBase64Service._();
    return _instance!;
  }

  /// Cache des images décodées.
  ///
  /// Borné par le volume total, pas par le nombre d'entrées : sur un
  /// téléphone de trois gigaoctets, c'est le volume qui étouffe.
  final Map<String, Uint8List> _decodeCache = {};
  int _cacheBytes = 0;

  /// Encode une image depuis son chemin en Base64
  /// Retourne null si le fichier n'existe pas
  Future<String?> encodeImageToBase64(String imagePath) async {
    try {
      final file = File(imagePath);
      
      if (!await file.exists()) {
        print('Image non trouvée: $imagePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      
      // Ajouter le préfixe pour identifier le type d'image
      final extension = imagePath.toLowerCase();
      String mimeType = 'image/jpeg';
      if (extension.endsWith('.png')) {
        mimeType = 'image/png';
      } else if (extension.endsWith('.gif')) {
        mimeType = 'image/gif';
      } else if (extension.endsWith('.webp')) {
        mimeType = 'image/webp';
      }
      
      return 'data:$mimeType;base64,$base64String';
    } catch (e) {
      print('Erreur encodage Base64: $e');
      return null;
    }
  }

  /// Encode plusieurs images en Base64
  /// Limite automatiquement à maxImages pour éviter les problèmes de taille
  Future<List<String>> encodeMultipleImages(
    List<String> imagePaths, {
    int maxImages = 3,
  }) async {
    final results = <String>[];
    final pathsToEncode = imagePaths.take(maxImages).toList();

    for (final path in pathsToEncode) {
      final encoded = await encodeImageToBase64(path);
      if (encoded != null) {
        results.add(encoded);
      }
    }

    return results;
  }

  /// Volume maximal retenu. Vingt-quatre mégaoctets suffisent à garder les
  /// avatars et les vignettes d'une liste entière.
  static const int _cacheMaxBytes = 24 * 1024 * 1024;

  /// Au-delà, une seule photo remplirait le cache à elle seule.
  static const int _cacheMaxEntry = 3 * 1024 * 1024;

  /// Clé courte dérivée de la chaîne.
  ///
  /// La première version prenait la chaîne base64 entière comme clé : une
  /// photo d'un mégaoctet était donc retenue deux fois, en clé et en
  /// valeur. La corriger en refusant les grosses images était pire encore —
  /// elles se redécodaient alors à chaque reconstruction, sur le thread
  /// d'interface. On ne garde ici que la longueur et les deux extrémités :
  /// deux images distinctes qui partageraient les trois n'existent pas en
  /// pratique, et la clé tient en cent trente caractères.
  static String _keyFor(String s) {
    if (s.length <= 128) return s;
    return '${s.length}:${s.substring(0, 64)}:${s.substring(s.length - 64)}';
  }

  /// Décode une chaîne Base64 en bytes pour affichage.
  ///
  /// Toutes les tailles passent par le cache désormais : c'est le volume
  /// total qui est borné, et les entrées les plus anciennes sortent
  /// d'abord.
  Uint8List? decodeBase64ToBytes(String base64String) {
    if (base64String.isEmpty) return null;

    final key = _keyFor(base64String);

    // Retirer puis réinsérer remet l'entrée en fin de file : les plus
    // anciennement utilisées partent en premier quand la borne est atteinte.
    final cached = _decodeCache.remove(key);
    if (cached != null) {
      _decodeCache[key] = cached;
      return cached;
    }

    try {
      // Retirer le prefixe data:image/xxx;base64, si present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }

      final bytes = base64Decode(cleanBase64.trim());
      _remember(key, bytes);
      return bytes;
    } catch (e) {
      debugPrint('Erreur decodage Base64: $e');
      return null;
    }
  }

  void _remember(String key, Uint8List bytes) {
    if (bytes.lengthInBytes > _cacheMaxEntry) return;

    _decodeCache[key] = bytes;
    _cacheBytes += bytes.lengthInBytes;

    while (_cacheBytes > _cacheMaxBytes && _decodeCache.isNotEmpty) {
      final oldest = _decodeCache.keys.first;
      final dropped = _decodeCache.remove(oldest);
      _cacheBytes -= dropped?.lengthInBytes ?? 0;
    }
  }

  /// Vide le cache. Appelé quand le système signale une pression mémoire.
  void clearCache() {
    _decodeCache.clear();
    _cacheBytes = 0;
  }

  /// Crée un widget Image à partir d'une chaîne Base64
  Widget? decodeBase64ToImage(
    String base64String, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    final bytes = decodeBase64ToBytes(base64String);
    if (bytes == null) return null;

    return Image.memory(
      bytes,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, color: Colors.grey),
        );
      },
    );
  }

  /// Estime la taille d'une image Base64 en bytes
  int estimateBase64Size(String base64String) {
    // Le Base64 augmente la taille d'environ 33%
    String cleanBase64 = base64String;
    if (base64String.contains(',')) {
      cleanBase64 = base64String.split(',').last;
    }
    return (cleanBase64.length * 0.75).round();
  }

  /// Vérifie si une chaîne est une image Base64 valide
  bool isValidBase64Image(String base64String) {
    try {
      if (!base64String.startsWith('data:image/')) {
        return false;
      }
      final bytes = decodeBase64ToBytes(base64String);
      return bytes != null && bytes.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
