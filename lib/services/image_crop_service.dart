import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/crop_screen.dart';

/// Service pour recadrer les images (profil ou notes)
/// Utilise un widget Flutter pur pour éviter les MissingPluginException
class ImageCropService {
  static final ImageCropService instance = ImageCropService._();
  ImageCropService._();

  /// Ouvre l'interface de recadrage pour une image
  Future<String?> cropImage(BuildContext context, String path, {bool isProfile = false}) async {
    try {
      final File file = File(path);
      if (!await file.exists()) return null;
      
      final Uint8List bytes = await file.readAsBytes();
      
      // Ouvrir l'écran de recadrage
      final croppedBytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => CropScreen(image: bytes, isProfile: isProfile),
        ),
      );

      if (croppedBytes == null) return null;

      // Sauvegarder le résultat dans un fichier temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(croppedBytes);

      return tempFile.path;
    } catch (e) {
      debugPrint('Erreur recadrage: $e');
      return null;
    }
  }
}
