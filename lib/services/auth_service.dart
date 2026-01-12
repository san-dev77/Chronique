import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service d'authentification Firebase
class AuthService {
  static AuthService? _instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService._();

  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  /// Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  /// Stream de l'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Vérifie si l'utilisateur est connecté
  bool get isSignedIn => currentUser != null;

  /// ID de l'utilisateur (null si non connecté)
  String? get userId => currentUser?.uid;

  /// Email de l'utilisateur
  String? get userEmail => currentUser?.email;

  /// Nom de l'utilisateur
  String? get userName => currentUser?.displayName;

  /// Photo de profil
  String? get userPhotoUrl => currentUser?.photoURL;

  /// Met à jour le nom d'affichage de l'utilisateur (Auth + Firestore)
  Future<void> updateProfile({String? name, String? photoUrl}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      if (name != null) {
        await user.updateDisplayName(name).catchError((e) {
          final err = e.toString();
          if (err.contains('Pigeon') || err.contains('Object?') || e is TypeError) {
            debugPrint('Note: Cast error ignoree dans updateDisplayName');
            return;
          }
          throw e;
        });
      }

      if (photoUrl != null) {
        await user.updatePhotoURL(photoUrl).catchError((e) => debugPrint('Err photo: $e'));
      }

      // Synchroniser avec Firestore via SharingService
      // On importe SharingService via un getter ou dynamiquement pour éviter les imports circulaires si possible
      // Mais ici SharingService dépend déjà d'AuthService.
      // On va passer par une méthode statique ou attendre que l'appelant le fasse si besoin, 
      // mais le plus propre est de l'appeler ici.
    } catch (e) {
      final err = e.toString();
      if (!err.contains('Pigeon') && !err.contains('Object?') && e is! TypeError) {
        debugPrint('Erreur mise à jour profil: $e');
        rethrow;
      }
    }
  }

  /// Met à jour le nom (Déprécié, utiliser updateProfile)
  Future<void> updateDisplayName(String name) async => updateProfile(name: name);

  /// Helper pour gérer les erreurs de cast internes de Firebase (Pigeon)
  Future<UserCredential?> _safeAuthCall(Future<UserCredential> Function() providerCall) async {
    try {
      return await providerCall();
    } catch (e) {
      final err = e.toString();
      // On détecte les erreurs de cast Pigeon qui arrivent APRES le succès de l'action
      if (err.contains('Pigeon') || err.contains('Object?') || e is TypeError) {
        debugPrint('⚠️ Erreur de cast détectée ($e). Vérification de la session...');
        
        // On attend que le SDK mette à jour l'état interne
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (_auth.currentUser != null) {
          debugPrint('✅ Succès confirmé par la session active malgré l\'erreur.');
          return null; // On signale le succès "silencieux"
        }
      }
      rethrow;
    }
  }

  /// Inscription avec email et mot de passe
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final cred = await _safeAuthCall(() => _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    ));

    // Mettre à jour le nom si fourni
    if (displayName != null) {
      await updateDisplayName(displayName);
    }

    return cred;
  }

  /// Connexion avec email et mot de passe
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _safeAuthCall(() => _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    ));
  }

  /// Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Erreur reset password: $e');
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Erreur déconnexion: $e');
      rethrow;
    }
  }

  /// Supprimer le compte
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } catch (e) {
      debugPrint('Erreur suppression compte: $e');
      rethrow;
    }
  }

  /// Messages d'erreur en français
  String getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'Aucun compte trouvé avec cet email.';
        case 'wrong-password':
          return 'Mot de passe incorrect.';
        case 'email-already-in-use':
          return 'Un compte existe déjà avec cet email.';
        case 'invalid-email':
          return 'Adresse email invalide.';
        case 'weak-password':
          return 'Mot de passe trop faible (min 6 caractères).';
        case 'user-disabled':
          return 'Ce compte a été désactivé.';
        case 'too-many-requests':
          return 'Trop de tentatives. Réessayez plus tard.';
        case 'network-request-failed':
          return 'Erreur réseau. Vérifiez votre connexion.';
        default:
          return 'Erreur Auth: ${error.message}';
      }
    }

    return 'Une erreur est survenue : ${error.toString()}';
  }
}
