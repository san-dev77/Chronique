import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import 'full_screen_image_viewer.dart';

/// Bandeau d'images en tete d'une chronique.
///
/// L'ancien affichage reprenait l'editeur de galerie : la premiere image
/// occupait toute la largeur en 16/10, ce qui donnait une photo de 800 px de
/// haut sur desktop, avant meme le premier mot du texte. La hauteur est
/// desormais bornee et les images suivantes tiennent dans une bande discrete.
class NoteHeroImage extends StatelessWidget {
  final List<String> imagePaths;
  final Color? auraColor;

  const NoteHeroImage({
    super.key,
    required this.imagePaths,
    this.auraColor,
  });

  /// Hauteur du bandeau : une fraction de la fenetre, plafonnee, pour que
  /// l'image accompagne le texte au lieu de l'ecraser.
  static double heightFor(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final byViewport = size.height * 0.36;
    final cap = Responsive.isWide(context) ? 380.0 : 260.0;
    return byViewport.clamp(180.0, cap);
  }

  void _open(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageViewer(photoUrl: path, tag: path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imagePaths.isEmpty) return const SizedBox.shrink();

    final height = heightFor(context);
    final rest = imagePaths.length > 1 ? imagePaths.sublist(1) : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Hero(
          path: imagePaths.first,
          height: height,
          auraColor: auraColor,
          onTap: () => _open(context, imagePaths.first),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: rest.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _Thumb(
                path: rest[i],
                onTap: () => _open(context, rest[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatefulWidget {
  final String path;
  final double height;
  final Color? auraColor;
  final VoidCallback onTap;

  const _Hero({
    required this.path,
    required this.height,
    required this.auraColor,
    required this.onTap,
  });

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final aura = widget.auraColor;

    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.enter,
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: (aura ?? Colors.black)
                    .withValues(alpha: _hover ? 0.34 : 0.18),
                blurRadius: _hover ? 30 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final dpr = MediaQuery.devicePixelRatioOf(context);
                    return AnimatedScale(
                      duration: AppMotion.slow,
                      curve: AppMotion.enter,
                      scale: _hover ? 1.035 : 1,
                      child: Image.file(
                        File(widget.path),
                        fit: BoxFit.cover,
                        cacheWidth: c.maxWidth.isFinite
                            ? (c.maxWidth * dpr).round()
                            : null,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.cardDark,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white38, size: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Voile bas : le texte qui suit se detache sans que l'image
                // soit assombrie sur toute sa hauteur.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: widget.height * 0.42,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.42),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (aura != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomLeft,
                            end: Alignment.topRight,
                            colors: [
                              aura.withValues(alpha: 0.22),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                AnimatedOpacity(
                  duration: AppMotion.fast,
                  opacity: _hover ? 1 : 0,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_out_map_rounded,
                                size: 14, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              'Agrandir',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatefulWidget {
  final String path;
  final VoidCallback onTap;

  const _Thumb({required this.path, required this.onTap});

  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 96,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover
                  ? Colors.white.withValues(alpha: 0.7)
                  : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Image.file(
              File(widget.path),
              fit: BoxFit.cover,
              cacheWidth: (96 * dpr).round(),
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.white12),
            ),
          ),
        ),
      ),
    );
  }
}
