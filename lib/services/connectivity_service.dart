import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  bool _isConnected = true;
  StreamSubscription<ConnectivityResult>? _subscription;

  /// Stream pour écouter les changements de connectivité
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// État actuel de la connectivité
  bool get isConnected => _isConnected;

  /// Initialise le service et commence à écouter les changements
  Future<void> initialize() async {
    // Vérifier l'état initial
    await _updateConnectionStatus();

    // Écouter les changements
    _subscription =
        _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      _updateConnectionStatus();
    });
  }

  /// Met à jour l'état de connexion
  Future<void> _updateConnectionStatus() async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();

      // Considérer comme connecté si connexion wifi, mobile ou ethernet
      final wasConnected = _isConnected;
      _isConnected = result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet;

      // Notifier uniquement si l'état a changé
      if (wasConnected != _isConnected) {
        print('🌐 Connectivité: ${_isConnected ? "En ligne" : "Hors ligne"}');
        _connectivityController.add(_isConnected);
      }
    } catch (e) {
      print('❌ Erreur vérification connectivité: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
  }

  /// Vérifie manuellement la connectivité
  Future<bool> checkConnection() async {
    await _updateConnectionStatus();
    return _isConnected;
  }

  /// Nettoie les ressources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}
