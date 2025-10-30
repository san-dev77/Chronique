import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service d'authentification Firebase
class AuthService {
  static AuthService? _instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  /// Connexion avec Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Déclencher le flux d'authentification Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // L'utilisateur a annulé
        return null;
      }

      // Obtenir les détails d'authentification
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Créer un nouveau credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Se connecter à Firebase avec le credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Erreur connexion Google: $e');
      rethrow;
    }
  }

  /// Inscription avec email et mot de passe
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mettre à jour le nom si fourni (sans reload qui cause l'erreur)
      if (displayName != null && userCredential.user != null) {
        try {
          await userCredential.user!.updateDisplayName(displayName);
        } catch (updateError) {
          print('Erreur mise à jour nom: $updateError');
          // Continue quand même
        }
      }

      return userCredential;
    } catch (e) {
      print('Erreur inscription: $e');
      rethrow;
    }
  }

  /// Connexion avec email et mot de passe
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Erreur connexion: $e');
      rethrow;
    }
  }

  /// Réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Erreur reset password: $e');
      rethrow;
    }
  }

  /// Déconnexion
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Erreur déconnexion: $e');
      rethrow;
    }
  }

  /// Supprimer le compte
  Future<void> deleteAccount() async {
    try {
      await currentUser?.delete();
    } catch (e) {
      print('Erreur suppression compte: $e');
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
          return 'Erreur: ${error.message}';
      }
    }
    return 'Une erreur est survenue.';
  }
}
