import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen_clean.dart';
import 'screens/main_screen.dart';
import 'screens/welcome_screen.dart';
import 'services/note_service.dart';
import 'services/image_storage_service.dart';
import 'services/connectivity_service.dart';
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

  runApp(const NoteKeeperApp());
}

class NoteKeeperApp extends StatelessWidget {
  const NoteKeeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Note Box',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreenClean(),
        '/welcome': (context) => const WelcomeScreen(),
        '/main': (context) => const MainScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
