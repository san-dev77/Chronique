import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen_clean.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/note_view_screen.dart';
import 'services/note_service.dart';
import 'services/image_storage_service.dart';
import 'services/connectivity_service.dart';
import 'services/memory_notification_service.dart';
import 'services/background_task_service.dart';
import 'services/accent_color_service.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Firebase: $e');
  }

  // Initialiser Hive
  final appDocumentDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocumentDir.path);

  // Initialiser le service de notes
  await NoteService.instance.initialize();

  // Initialiser le service de stockage d'images
  await ImageStorageService.instance.initialize();

  // Initialiser le service de connectivité
  await ConnectivityService.instance.initialize();

  // Initialiser le service de notifications de souvenirs
  try {
    await MemoryNotificationService.instance.init();
    final hasPermission =
        await MemoryNotificationService.instance.requestPermission();
    debugPrint('Permission notifications: $hasPermission');
    if (hasPermission) {
      MemoryNotificationService.instance.checkAndNotifyMemories();
    }
  } catch (e) {
    debugPrint('Notifications non disponibles: $e');
  }

  // Initialiser les tâches de fond
  try {
    await BackgroundTaskService.instance.init();
    final taskEnabled = await BackgroundTaskService.instance.isTaskEnabled();
    if (taskEnabled) {
      await BackgroundTaskService.instance.startMemoriesTask();
    }
  } catch (e) {
    debugPrint('Taches de fond non disponibles: $e');
  }

  // Initialiser le service de couleur d'accent
  await AccentColorService.instance.init();

  // Initialiser le service de theme
  await ThemeService.instance.init();

  runApp(NoteKeeperApp());
}

class NoteKeeperApp extends StatefulWidget {
  const NoteKeeperApp({super.key});

  @override
  State<NoteKeeperApp> createState() => _NoteKeeperAppState();
}

class _NoteKeeperAppState extends State<NoteKeeperApp> {
  @override
  void initState() {
    super.initState();
    // Configurer le callback pour ouvrir une note depuis la notification
    MemoryNotificationService.instance.onOpenNote = _openNote;
  }

  void _openNote(String noteId) async {
    debugPrint('Ouverture de la note depuis notification: $noteId');

    // Récupérer la note par son ID
    final notes = NoteService.instance.getAllNotes();
    final note = notes.where((n) => n.id == noteId).firstOrNull;

    if (note != null) {
      // Naviguer vers la vue de la note
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => NoteViewScreen(
            note: note,
            onEdit: () => navigatorKey.currentState?.pop(),
            onDelete: () async {
              await NoteService.instance.deleteNote(note.id);
              navigatorKey.currentState?.pop();
            },
            onToggleFavorite: () async {
              await NoteService.instance.saveNote(
                note.copyWith(isFavorite: !note.isFavorite),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ecouter les changements de couleur ET de theme
    return ListenableBuilder(
      listenable: Listenable.merge([
        AccentColorService.instance,
        ThemeService.instance,
      ]),
      builder: (context, child) {
        final accentColor = AccentColorService.instance.accentColor;
        final themeMode = ThemeService.instance.themeMode;

        // Status bar avec la couleur d'accent
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: accentColor,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ));

        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Note Box',
          theme: AppTheme.getLightTheme(accentColor),
          darkTheme: AppTheme.getDarkTheme(accentColor),
          themeMode: themeMode,
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreenClean(),
            '/welcome': (context) => const WelcomeScreen(),
            '/main': (context) {
              final args = ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
              final initialTab = args?['initialTab'] as int? ?? 0;
              return MainScreen(initialTab: initialTab);
            },
          },
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
