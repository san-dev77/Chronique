import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import '../widgets/auth_shell.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/sharing_service.dart';
import '../services/image_base64_service.dart';
import '../services/image_crop_service.dart';
import '../widgets/primary_button.dart';
import '../widgets/note_logo.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_theme.dart';

/// Écran de connexion simplifié (Email + Mot de passe uniquement)
class AuthLoginScreen extends StatefulWidget {
  final bool initialIsSignUp;
  const AuthLoginScreen({super.key, this.initialIsSignUp = false});

  @override
  State<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends State<AuthLoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;
  late bool _isSignUp;

  // Avatar state
  int? _profileColor;
  String? _profilePhotoBase64;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialIsSignUp;
    // Couleur aleatoire par défaut
    _profileColor = AppTheme.skyBlue.value; // TODO: Randomize?

    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // --- Avatar Logic ---

  Future<void> _showAvatarPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisir un avatar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAvatarOption(Icons.photo_library_rounded, 'Galerie', () {
                  Navigator.pop(context);
                  _pickImage();
                }),
                _buildAvatarOption(Icons.palette_rounded, 'Couleur', () {
                  Navigator.pop(context);
                  _showColorPicker();
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarOption(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 70,
    );

    if (image != null && mounted) {
      try {
        final croppedPath = await ImageCropService.instance
            .cropImage(context, image.path, isProfile: true);
        if (croppedPath == null) return;

        final base64 =
            await ImageBase64Service.instance.encodeImageToBase64(croppedPath);
        if (base64 != null) {
          setState(() {
            _profilePhotoBase64 = base64;
            _profileColor = null; // Reset color if image is picked
          });
        }
      } catch (e) {
        debugPrint('Erreur image picker: $e');
      }
    }
  }

  void _showColorPicker() {
    final colors = [
      AppTheme.skyBlue,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.blueGrey,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choisir une couleur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              height: 100,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: colors.length,
                itemBuilder: (context, index) {
                  final color = colors[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _profileColor = color.value;
                        _profilePhotoBase64 =
                            null; // Reset image if color is picked
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.4), blurRadius: 8)
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleEmailAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isSignUp) {
        // Inscription
        await AuthService.instance.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );

        // Attendre un peu pour que Firebase finalise
        await Future.delayed(const Duration(milliseconds: 500));

        // Enregistrer dans Firestore avec Avatar
        await SharingService.instance.registerCurrentUser(
          name: _nameController.text.trim(),
          photoBase64: _profilePhotoBase64,
          profileColor: _profileColor,
        );
      } else {
        // Connexion
        await AuthService.instance.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Sync Firestore profile
        await SharingService.instance.registerCurrentUser();
      }

      // Si on arrive ici, l'auth a réussi
      if (!mounted) return;

      // Sync après authentification (non bloquante)
      try {
        await CloudSyncService.instance.syncAll();
      } catch (syncError) {
        print('Erreur sync après auth: $syncError');
      }

      if (!mounted) return;

      // Redirection vers l'app
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      print('Erreur auth: $e');

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AuthService.instance.getErrorMessage(e)),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.skyBlue;
    // L'ecran forcait le mode clair : passer d'une app sombre a un formulaire
    // blanc puis revenir au sombre etait desagreable. Il suit le theme.
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary =
        isDark ? AppTheme.textMutedDark : const Color(0xFF4A4A4A);

    return AuthShell(
      tagline: _isSignUp
          ? 'Commencez\nvotre chronique.'
          : 'Content de\nvous revoir.',
      leading: AuthBackButton(
        onTap: () {
          // Si cet ecran est seul dans la pile — cas d'une deconnexion qui
          // l'a videe — depiler laisserait un ecran noir.
          if (Navigator.of(context).canPop()) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/welcome');
          }
        },
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Form(
            key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            // Logo et Titre
                            Center(
                              child: Column(
                                children: [
                                  Hero(
                                    tag: 'app_logo',
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: primary.withOpacity(0.2),
                                            blurRadius: 20,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: const NoteLogo(
                                          size: 60, isRound: true),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _isSignUp
                                        ? 'Créer un compte'
                                        : 'Bon retour !',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _isSignUp
                                        ? 'Rejoignez la communauté Note Keeper'
                                        : 'Connectez-vous pour continuer',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 40),

                            // Avatar Picker (Inscription uniquement)
                            if (_isSignUp) ...[
                              Center(
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: _showAvatarPicker,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.1),
                                              blurRadius: 15,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: UserAvatar(
                                          displayName:
                                              _nameController.text.isNotEmpty
                                                  ? _nameController.text
                                                  : '?',
                                          photoBase64: _profilePhotoBase64,
                                          profileColor: _profileColor,
                                          radius: 50,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 3),
                                          boxShadow: [
                                            BoxShadow(
                                              color: primary.withOpacity(0.4),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                            Icons.camera_alt_rounded,
                                            color: Colors.white,
                                            size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 30),

                              // Champ Nom
                              _buildTextField(
                                controller: _nameController,
                                label: 'Nom d\'affichage',
                                icon: Icons.person_rounded,
                                isCapitalized: true,
                                onChanged: (v) => setState(() {}),
                                validator: (v) =>
                                    _isSignUp && (v == null || v.trim().isEmpty)
                                        ? 'Nom requis'
                                        : null,
                              ),
                              const SizedBox(height: 20),
                            ],

                            // Champ Email
                            _buildTextField(
                              controller: _emailController,
                              label: 'Adresse Email',
                              icon: Icons.alternate_email_rounded,
                              inputType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty)
                                  return 'Email requis';
                                if (!v.contains('@')) return 'Email invalide';
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Champ Mot de passe
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Mot de passe',
                              icon: Icons.lock_rounded,
                              isPassword: true,
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Mot de passe requis';
                                if (_isSignUp && v.length < 6)
                                  return 'Minimum 6 caractères';
                                return null;
                              },
                            ),

                            const SizedBox(height: 40),

                            // Bouton Principal
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withOpacity(0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: PrimaryButton(
                                text: _isSignUp
                                    ? 'Créer mon compte'
                                    : 'Se connecter',
                                onPressed: _isLoading ? null : _handleEmailAuth,
                                isLoading: _isLoading,
                              ),
                            ),

                            const SizedBox(height: 30),

                            // Toggle
                            Center(
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() => _isSignUp = !_isSignUp);
                                        // Reset animations or state if needed
                                      },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontFamily: 'Inter',
                                      color: textColor, // Explicit black
                                    ),
                                    children: [
                                      TextSpan(
                                        text: _isSignUp
                                            ? 'Déjà un compte ? '
                                            : 'Pas de compte ? ',
                                        style: TextStyle(
                                            color: Colors.white), // Forced White
                                      ),
                                      TextSpan(
                                        text: _isSignUp
                                            ? 'Se connecter'
                                            : 'S\'inscrire',
                                        style: TextStyle(
                                          color: Colors.white, // Forced White
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool isPassword = false,
    bool isCapitalized = false,
    ValueChanged<String>? onChanged,
    String? Function(String?)? validator,
  }) {
    // Force field colors independent of theme
    const fieldColor = Colors.white;
    const fieldTextColor = Color(0xFF2D3436);
    const fieldLabelColor = Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: fieldColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: inputType,
        textCapitalization: isCapitalized
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: fieldTextColor,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: fieldLabelColor.shade500,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          prefixIcon: Icon(icon,
              color: Theme.of(context).primaryColor.withOpacity(0.7)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                    color: fieldLabelColor.shade400,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Colors.transparent),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
                color: Theme.of(context).primaryColor.withOpacity(0.5),
                width: 1.5),
          ),
          filled: true,
          fillColor: fieldColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          errorStyle: const TextStyle(height: 0.8),
        ),
      ),
    );
  }
}
