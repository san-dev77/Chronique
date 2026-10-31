import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/image_crop_service.dart';
import '../theme/app_theme.dart';

class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// Picks an image from gallery and shows a preview dialog with optional cropping.
  /// Returns the final path or null if picking/cancelling.
  static Future<String?> pickAndOptionallyCrop(BuildContext context, {bool isProfile = false}) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: isProfile ? 400 : 1920,
      maxHeight: isProfile ? 400 : 1920,
      imageQuality: isProfile ? 70 : 85,
    );

    if (image == null) return null;

    if (!context.mounted) return image.path;

    String? currentLocalPath = image.path;

    // Show selection dialog with preview
    if (!context.mounted) return currentLocalPath;

    final String? finalPath = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return AlertDialog(
            backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            title: Row(
              children: [
                Icon(Icons.image_search_rounded, color: AppTheme.skyBlue),
                const SizedBox(width: 12),
                const Text(
                  'Aperçu de l\'image',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.4,
                        ),
                        child: Image.file(
                          File(currentLocalPath!),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Bouton recadrer sur l'image
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FloatingActionButton.small(
                        heroTag: 'crop_btn_${DateTime.now().millisecondsSinceEpoch}',
                        onPressed: () async {
                          try {
                            final String? cropped = await ImageCropService.instance.cropImage(
                              context,
                              currentLocalPath!,
                              isProfile: isProfile
                            );
                            if (cropped != null) {
                              setDialogState(() {
                                currentLocalPath = cropped;
                              });
                            }
                          } catch (e) {
                            debugPrint('Erreur recadrage: $e');
                          }
                        },
                        backgroundColor: AppTheme.skyBlue,
                        child: const Icon(Icons.crop_rotate_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  isProfile 
                    ? 'Vous pouvez recadrer votre photo pour l\'ajuster perfectly.'
                    : 'Ajustez l\'image ou validez pour l\'ajouter à votre chronique.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(
                  'Annuler',
                  style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, currentLocalPath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.skyBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Valider l\'image'),
              ),
            ],
          );
        },
      ),
    );

    return finalPath;
  }
}
