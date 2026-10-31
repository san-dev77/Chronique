import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../screens/crop_screen.dart';
import 'image_storage_service.dart';

/// Service pour recadrer les images (profil ou notes)
/// Utilise un widget Flutter pur pour éviter les MissingPluginException
class ImageCropService {
  static final ImageCropService instance = ImageCropService._();
  ImageCropService._();

  /// Ouvre l'interface de recadrage pour une image.
  ///
  /// Retourne le chemin du résultat, ou `null` si l'utilisateur a renoncé.
  /// Lève une exception si le recadrage a échoué : l'appelant doit le dire,
  /// car perdre une photo en silence est le pire des deux maux.
  ///
  /// Le résultat va directement dans le stockage permanent. La première
  /// version l'écrivait dans `getTemporaryDirectory()` : sur un téléphone
  /// à court d'espace, Android vide ces dossiers pour se faire de la place,
  /// et l'image disparaissait entre le recadrage et l'enregistrement de la
  /// chronique. Le symptôme était déroutant — l'image n'était perdue que si
  /// on passait par le recadrage, jamais avec « Garder tel quel », parce
  /// que ce chemin-là laissait moins de temps au système pour frapper.
  Future<String?> cropImage(
    BuildContext context,
    String path, {
    bool isProfile = false,
  }) async {
    final File file = File(path);
    if (!await file.exists()) {
      throw Exception('Image introuvable : $path');
    }

    final Uint8List bytes = await file.readAsBytes();
    if (!context.mounted) return null;

    final croppedBytes = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(image: bytes, isProfile: isProfile),
      ),
    );

    // L'utilisateur a fermé l'écran : ce n'est pas une erreur.
    if (croppedBytes == null) return null;

    return ImageStorageService.instance.saveImageFromBytes(croppedBytes, 'jpg');
  }
}
