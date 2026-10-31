import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/image_base64_service.dart';
import '../theme/app_theme.dart';

/// Un widget réutilisable pour afficher l'avatar d'un utilisateur
/// Supporte: Image Base64, URL Image (Google), ou Initiale avec couleur.
class UserAvatar extends StatelessWidget {
  final String? photoBase64;
  final String? photoUrl;
  final String displayName;
  final int? profileColor;
  final double radius;
  final String? userId;

  const UserAvatar({
    super.key,
    this.photoBase64,
    this.photoUrl,
    required this.displayName,
    this.profileColor,
    this.radius = 20,
    this.userId,
    this.heroTag,
    this.onTap,
  });

  final String? heroTag;

  /// Action au clic. Par defaut, un apercu compact de la photo.
  /// Les Reglages y branchent le choix d'une nouvelle image : sans cela, le
  /// GestureDetector interne captait le clic et on ne pouvait plus la changer.
  final VoidCallback? onTap;

  /// Cache statique pour les profils Firestore afin d'éviter les flickering au scroll
  static final Map<String, Map<String, dynamic>> _profileCache = {};

  @override
  Widget build(BuildContext context) {
    if (userId != null &&
        photoBase64 == null &&
        photoUrl == null &&
        profileColor == null) {
      
      // Utiliser le cache si disponible
      if (_profileCache.containsKey(userId!)) {
        final data = _profileCache[userId]!;
        return _buildAvatarWidget(
          context,
          photoBase64: data['photoBase64'],
          photoUrl: data['photoURL'],
          color: data['profileColor'],
        );
      }

      return FutureBuilder<DocumentSnapshot>(
        future:
            FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            
            // Mettre en cache
            _profileCache[userId!] = data;
            
            return _buildAvatarWidget(
              context,
              photoBase64: data['photoBase64'],
              photoUrl: data['photoURL'],
              color: data['profileColor'],
            );
          }
          return _buildAvatarWidget(context);
        },
      );
    }

    return _buildAvatarWidget(
      context,
      photoBase64: photoBase64,
      photoUrl: photoUrl,
      color: profileColor,
    );
  }

  Widget _buildAvatarWidget(
    BuildContext context, {
    String? photoBase64,
    String? photoUrl,
    int? color,
  }) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final hasImage = (photoBase64 != null && photoBase64.isNotEmpty) ||
        (photoUrl != null && photoUrl.isNotEmpty);

    Widget avatar;

    if (photoBase64 != null && photoBase64.isNotEmpty) {
      final bytes =
          ImageBase64Service.instance.decodeBase64ToBytes(photoBase64);
      // Sans ResizeImage, une photo de profil de 1000x1000 occupait quatre
      // megaoctets de texture pour un rond de quarante pixels — et l'avatar
      // apparait sur plusieurs ecrans a la fois.
      final side = (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round();
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: bytes != null
            ? ResizeImage(MemoryImage(bytes), width: side, height: side)
            : null,
      );
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      final bgColor =
          color != null ? Color(color) : AppTheme.skyBlue.withOpacity(0.12);
      final textColor = color != null ? Colors.white : AppTheme.skyBlue;
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      );
    }

    if (!hasImage) {
      if (onTap == null) return avatar;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onTap, child: avatar),
      );
    }

    // Le tag par defaut etait 'avatar_<uid>', donc identique pour toutes les
    // occurrences de l'avatar de l'utilisateur courant. Depuis que les onglets
    // vivent dans un IndexedStack, ils sont tous montes en meme temps :
    // quatre Hero de meme tag coexistaient, ce que Flutter refuse.
    // Un Hero ne sert qu'a animer une transition de route : on ne l'active
    // donc que si l'appelant fournit un tag explicite, unique par nature.
    final tag = heroTag;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // Une vignette de 40 px n'a pas besoin d'un visualiseur plein ecran
        // noir : un simple apercu centre suffit, et on en sort d'un clic.
        onTap: onTap ?? () => _showPreview(context),
        child: tag == null ? avatar : Hero(tag: tag, child: avatar),
      ),
    );
  }

  /// Apercu compact de la photo de profil.
  void _showPreview(BuildContext context) {
    Uint8List? bytes;
    if (photoBase64 != null) {
      bytes = ImageBase64Service.instance.decodeBase64ToBytes(photoBase64!);
    }

    Widget image;
    if (bytes != null) {
      image = Image.memory(bytes, fit: BoxFit.cover);
    } else if (photoUrl != null && !photoUrl!.startsWith('http')) {
      image = Image.file(File(photoUrl!), fit: BoxFit.cover);
    } else if (photoUrl != null) {
      image = Image.network(photoUrl!, fit: BoxFit.cover);
    } else {
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 260,
                height: 260,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                  border: Border.all(color: Colors.white24, width: 3),
                ),
                child: image,
              ),
              const SizedBox(height: 20),
              if (displayName.isNotEmpty)
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 6),
              Text(
                'Cliquez pour fermer',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
