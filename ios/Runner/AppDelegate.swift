import Flutter
import UIKit
import workmanager

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Les greffons doivent etre enregistres une seconde fois pour l'isolat
    // des taches de fond : il demarre hors de l'application, sans rien de ce
    // qui a ete monte ci-dessus. Sans cela, le travailleur des souvenirs
    // n'aurait acces ni a Hive, ni aux notifications, ni a Firebase.
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Les memes identifiants que ceux declares dans Info.plist sous
    // BGTaskSchedulerPermittedIdentifiers : iOS refuse d'executer une tache
    // dont le nom n'y figure pas.
    WorkmanagerPlugin.registerTask(withIdentifier: "notebox_memories_task")
    WorkmanagerPlugin.registerTask(withIdentifier: "notebox_memories_oneoff_task")

    // Cadence minimale demandee au systeme. iOS n'en fait qu'a sa tete — il
    // observe les habitudes avant d'accorder du temps — mais sans cet appel
    // il n'accorde rien du tout.
    UIApplication.shared.setMinimumBackgroundFetchInterval(
      TimeInterval(60 * 30))

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
