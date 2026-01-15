import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:crop_your_image/crop_your_image.dart';
import '../theme/app_theme.dart';

class CropScreen extends StatefulWidget {
  final Uint8List image;
  final bool isProfile;

  const CropScreen({super.key, required this.image, this.isProfile = false});

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isProfile ? 'Recadrer Profil' : 'Recadrer Image',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isCropping)
            TextButton(
              onPressed: () {
                setState(() => _isCropping = true);
                _controller.crop();
              },
              child: Text(
                'APPLIQUER',
                style: TextStyle(color: AppTheme.skyBlue, fontWeight: FontWeight.bold),
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.skyBlue),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.image,
              controller: _controller,
              onCropped: (image) {
                Navigator.pop(context, image);
              },
              aspectRatio: widget.isProfile ? 1 : null,
              initialSize: 0.8,
              maskColor: Colors.black.withOpacity(0.5),
              baseColor: Colors.black,
              cornerDotBuilder: (size, edgeAlignment) => DotControl(color: AppTheme.skyBlue),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRatioButton('Original', null),
                if (!widget.isProfile) ...[
                  _buildRatioButton('1:1', 1.0),
                  _buildRatioButton('4:3', 4 / 3),
                  _buildRatioButton('16:9', 16 / 9),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioButton(String label, double? ratio) {
    return GestureDetector(
      onTap: () => _controller.aspectRatio = ratio,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class DotControl extends StatelessWidget {
  final Color color;
  const DotControl({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
