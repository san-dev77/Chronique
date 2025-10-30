import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';
import 'note_service.dart';

class BackupService {
  static BackupService? _instance;

  BackupService._();

  static BackupService get instance {
    _instance ??= BackupService._();
    return _instance!;
  }

  /// Exporte toutes les notes avec leurs images dans un dossier de backup
  Future<String> exportAllNotes() async {
    try {
      // Récupérer toutes les notes
      final notes = NoteService.instance.getAllNotes();

      // Créer un dossier de backup avec timestamp
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${appDir.path}/NoteBoxBackup_$timestamp');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Créer un dossier pour les images
      final imagesDir = Directory('${backupDir.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Préparer les données avec chemins relatifs pour les images
      final backupData = <Map<String, dynamic>>[];

      for (var note in notes) {
        final noteData = note.toJson();
        final newImagePaths = <String>[];

        // Copier chaque image dans le dossier backup
        for (var imagePath in note.imagePaths) {
          try {
            final imageFile = File(imagePath);
            if (await imageFile.exists()) {
              final fileName = imagePath.split('/').last;
              final newPath = '${imagesDir.path}/$fileName';
              await imageFile.copy(newPath);
              newImagePaths.add('images/$fileName'); // Chemin relatif
            }
          } catch (e) {
            print('Erreur copie image $imagePath: $e');
          }
        }

        noteData['imagePaths'] = newImagePaths;
        backupData.add(noteData);
      }

      // Sauvegarder le JSON
      final jsonFile = File('${backupDir.path}/notes_backup.json');
      await jsonFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(backupData),
      );

      return backupDir.path;
    } catch (e) {
      throw Exception('Erreur lors de l\'export: $e');
    }
  }

  /// Importe les notes depuis un dossier de backup
  Future<int> importNotesFromBackup(String backupPath) async {
    try {
      final backupDir = Directory(backupPath);
      if (!await backupDir.exists()) {
        throw Exception('Dossier de backup introuvable');
      }

      // Lire le fichier JSON
      final jsonFile = File('$backupPath/notes_backup.json');
      if (!await jsonFile.exists()) {
        throw Exception('Fichier notes_backup.json introuvable');
      }

      final jsonString = await jsonFile.readAsString();
      final List<dynamic> backupData = jsonDecode(jsonString);

      // Récupérer le dossier des images de l'app
      final appDir = await getApplicationDocumentsDirectory();
      final appImagesDir = Directory('${appDir.path}/note_images');
      if (!await appImagesDir.exists()) {
        await appImagesDir.create(recursive: true);
      }

      int importedCount = 0;

      for (var noteData in backupData) {
        try {
          final data = Map<String, dynamic>.from(noteData);
          final List<String> newImagePaths = [];

          // Restaurer les images
          for (var relativePath
              in (data['imagePaths'] as List<dynamic>? ?? [])) {
            try {
              final backupImageFile = File('$backupPath/$relativePath');
              if (await backupImageFile.exists()) {
                final fileName = relativePath.toString().split('/').last;
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final newFileName = '${timestamp}_$fileName';
                final newPath = '${appImagesDir.path}/$newFileName';

                await backupImageFile.copy(newPath);
                newImagePaths.add(newPath);
              }
            } catch (e) {
              print('Erreur restauration image $relativePath: $e');
            }
          }

          data['imagePaths'] = newImagePaths;

          // Restaurer la note
          final note = Note.fromJson(data);
          await NoteService.instance.saveNote(note);
          importedCount++;
        } catch (e) {
          print('Erreur import note: $e');
        }
      }

      return importedCount;
    } catch (e) {
      throw Exception('Erreur lors de l\'import: $e');
    }
  }

  /// Exporte vers un fichier unique (JSON avec images encodées en base64)
  Future<String> exportToSingleFile() async {
    try {
      final notes = NoteService.instance.getAllNotes();
      final appDir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];

      final backupData = <Map<String, dynamic>>[];

      for (var note in notes) {
        final noteData = note.toJson();
        final encodedImages = <String>[];

        // Encoder les images en base64
        for (var imagePath in note.imagePaths) {
          try {
            final imageFile = File(imagePath);
            if (await imageFile.exists()) {
              final bytes = await imageFile.readAsBytes();
              final base64Image = base64Encode(bytes);
              final extension = imagePath.split('.').last;
              encodedImages.add('data:image/$extension;base64,$base64Image');
            }
          } catch (e) {
            print('Erreur encodage image $imagePath: $e');
          }
        }

        noteData['imagesBase64'] = encodedImages;
        noteData.remove('imagePaths');
        backupData.add(noteData);
      }

      final exportData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'notesCount': backupData.length,
        'notes': backupData,
      };

      final exportFile = File('${appDir.path}/NoteBox_Export_$timestamp.json');
      await exportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );

      return exportFile.path;
    } catch (e) {
      throw Exception('Erreur lors de l\'export unique: $e');
    }
  }

  /// Importe depuis un fichier unique (avec images base64)
  Future<int> importFromSingleFile(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Fichier introuvable');
      }

      final jsonString = await file.readAsString();
      final exportData = jsonDecode(jsonString) as Map<String, dynamic>;
      final notes = exportData['notes'] as List<dynamic>;

      final appDir = await getApplicationDocumentsDirectory();
      final appImagesDir = Directory('${appDir.path}/note_images');
      if (!await appImagesDir.exists()) {
        await appImagesDir.create(recursive: true);
      }

      int importedCount = 0;

      for (var noteData in notes) {
        try {
          final data = Map<String, dynamic>.from(noteData);
          final List<String> newImagePaths = [];

          // Décoder les images base64
          final imagesBase64 = data['imagesBase64'] as List<dynamic>? ?? [];
          for (int i = 0; i < imagesBase64.length; i++) {
            try {
              final base64String = imagesBase64[i].toString();
              if (base64String.startsWith('data:image/')) {
                final parts = base64String.split(',');
                if (parts.length == 2) {
                  final bytes = base64Decode(parts[1]);
                  final extension = base64String.split(';')[0].split('/')[1];
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  final fileName = 'restored_${timestamp}_$i.$extension';
                  final filePath = '${appImagesDir.path}/$fileName';

                  final imageFile = File(filePath);
                  await imageFile.writeAsBytes(bytes);
                  newImagePaths.add(filePath);
                }
              }
            } catch (e) {
              print('Erreur décodage image $i: $e');
            }
          }

          data['imagePaths'] = newImagePaths;
          data.remove('imagesBase64');

          final note = Note.fromJson(data);
          await NoteService.instance.saveNote(note);
          importedCount++;
        } catch (e) {
          print('Erreur import note: $e');
        }
      }

      return importedCount;
    } catch (e) {
      throw Exception('Erreur lors de l\'import: $e');
    }
  }
}
