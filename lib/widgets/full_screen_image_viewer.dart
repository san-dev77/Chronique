import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/image_base64_service.dart';

class FullScreenImageViewer extends StatelessWidget {
  final String? photoUrl;
  final String? photoBase64;
  final String? tag;

  const FullScreenImageViewer({
    super.key,
    this.photoUrl,
    this.photoBase64,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (photoBase64 != null) {
      bytes = ImageBase64Service.instance.decodeBase64ToBytes(photoBase64!);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Image avec Zoom & Pan
          Center(
            child: Hero(
              tag: tag ?? 'avatar_${photoUrl ?? photoBase64 ?? "none"}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: _buildImage(context, bytes),
              ),
            ),
          ),
          
          // Bouton Fermer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage(BuildContext context, Uint8List? bytes) {
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
      );
    }
    
    if (photoUrl != null) {
      return Image.network(
        photoUrl!,
        fit: BoxFit.contain,
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        errorBuilder: (context, error, stackTrace) => _errorWidget(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        },
      );
    }

    return _errorWidget();
  }

  Widget _errorWidget() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, color: Colors.white54, size: 64),
        SizedBox(height: 16),
        Text(
          'Impossible de charger l\'image',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }
}
