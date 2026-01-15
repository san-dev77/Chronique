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

  /// Cache pour éviter de re-décoder les mêmes chaînes Base64 à chaque frame
  final Map<String, Uint8List> _decodeCache = {};

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

  /// Décode une chaîne Base64 en bytes pour affichage
  Uint8List? decodeBase64ToBytes(String base64String) {
    if (base64String.isEmpty) return null;
    
    // Vérifier le cache
    if (_decodeCache.containsKey(base64String)) {
      return _decodeCache[base64String];
    }

    try {
      // Retirer le préfixe data:image/xxx;base64, si présent
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }
      
      final bytes = base64Decode(cleanBase64.trim());
      
      // Mettre en cache (limiter la taille si nécessaire, mais ici on garde simple)
      if (_decodeCache.length > 100) _decodeCache.clear(); // Flush si trop gros
      _decodeCache[base64String] = bytes;
      
      return bytes;
    } catch (e) {
      print('Erreur décodage Base64: $e');
      return null;
    }
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
