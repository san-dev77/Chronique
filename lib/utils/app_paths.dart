import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Emplacement de stockage des donnees de l'application.
class AppPaths {
  const AppPaths._();

  static Directory? _cached;

  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS;

  /// Racine de stockage des donnees.
  ///
  /// Sur desktop, `getApplicationDocumentsDirectory()` renvoie « Mes Documents »,
  /// qui est tres souvent redirige vers OneDrive. Y placer la base Hive et les
  /// photos provoque trois ennuis bien reels :
  ///   - OneDrive verrouille les fichiers pendant la synchronisation, ce qui
  ///     fait echouer l'ouverture de la base (PathAccessException) ;
  ///   - un conflit de synchronisation duplique la base et perd des notes ;
  ///   - toutes les photos partent dans le cloud personnel a l'insu de
  ///     l'utilisateur, en doublon de la synchronisation Firebase.
  ///
  /// Les donnees applicatives vont donc dans le dossier de support de l'app
  /// (%APPDATA% sous Windows), qui n'est jamais synchronise.
  static Future<Directory> storageRoot() async {
    final cached = _cached;
    if (cached != null) return cached;

    final dir = isDesktop
        ? await getApplicationSupportDirectory()
        : await getApplicationDocumentsDirectory();

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    _cached = dir;
    return dir;
  }
}
