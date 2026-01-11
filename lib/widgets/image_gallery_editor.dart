import 'package:flutter/material.dart';
import 'dart:io';

class ImageGalleryEditor extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int)? onRemove;
  final Color textColor;
  final bool readOnly;

  const ImageGalleryEditor({
    super.key,
    required this.imagePaths,
    this.onRemove,
    required this.textColor,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Une seule image : affichage en grand
        if (imagePaths.length == 1)
          _buildSingleImage(imagePaths[0], 0)
        
        // Deux images : grille 2 colonnes
        else if (imagePaths.length == 2)
          Row(
            children: [
              Expanded(child: _buildGridImage(imagePaths[0], 0)),
              const SizedBox(width: 12),
              Expanded(child: _buildGridImage(imagePaths[1], 1)),
            ],
          )
        
        // Trois images ou plus : disposition mixte
        else
          Column(
            children: [
              // Première image en grand
              _buildSingleImage(imagePaths[0], 0),
              const SizedBox(height: 12),
              // Autres images en grille
              _buildImageGrid(),
            ],
          ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSingleImage(String path, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
            ),
          ),
          _buildRemoveButton(index),
        ],
      ),
    );
  }

  Widget _buildGridImage(String path, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Image.file(
              File(path),
              fit: BoxFit.cover,
            ),
          ),
          _buildRemoveButton(index),
        ],
      ),
    );
  }

  Widget _buildImageGrid() {
    final remaining = imagePaths.sublist(1);
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: remaining.length,
      itemBuilder: (context, index) {
        return _buildGridImage(remaining[index], index + 1);
      },
    );
  }

  Widget _buildRemoveButton(int index) {
    if (readOnly || onRemove == null) return const SizedBox.shrink();
    
    return Positioned(
      top: 8,
      right: 8,
      child: GestureDetector(
        onTap: () => onRemove!(index),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close,
            size: 16,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

