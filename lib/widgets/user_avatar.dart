import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/image_base64_service.dart';
import 'full_screen_image_viewer.dart';
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
  });

  final String? heroTag;

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
      avatar = CircleAvatar(
        radius: radius,
        backgroundImage: bytes != null ? MemoryImage(bytes) : null,
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

    if (!hasImage) return avatar;

    final tag = heroTag ?? 'avatar_${userId ?? displayName}';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FullScreenImageViewer(
            photoBase64: photoBase64,
            photoUrl: photoUrl,
            tag: tag,
          ),
        ),
      ),
      child: Hero(
        tag: tag,
        child: avatar,
      ),
    );
  }
}
