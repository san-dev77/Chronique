import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/note.dart';
import '../models/note_mood.dart';
import '../services/image_crop_service.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/aura_glow_widget.dart';
import '../widgets/aura_picker_sheet.dart';
import 'note_edit_screen.dart';

/// Assistant de creation d'une chronique.
///
/// L'ancien parcours ouvrait directement un formulaire vide : l'image et
/// l'aura etaient enfouies dans des menus, donc rarement utilisees. On pose
/// desormais le decor d'abord — image, cadrage, aura — puis on ecrit.
class NoteComposeFlow extends StatefulWidget {
  final Future<void> Function(Note note) onSave;

  const NoteComposeFlow({super.key, required this.onSave});

  @override
  State<NoteComposeFlow> createState() => _NoteComposeFlowState();
}

enum _Step { image, crop, aura }

class _NoteComposeFlowState extends State<NoteComposeFlow> {
  _Step _step = _Step.image;
  String? _imagePath;
  String? _moodKey;
  int? _moodColor;
  bool _busy = false;


  Color get _accent => _moodKey == null
      ? AppTheme.skyBlue
      : NoteMood.getEffectiveColor(_moodKey, _moodColor);

  int get _stepIndex => switch (_step) {
        _Step.image => 0,
        _Step.crop => 1,
        _Step.aura => 2,
      };

  // ---------------------------------------------------------------- actions

  Future<void> _pickImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() {
          _imagePath = picked.path;
          _step = _Step.crop;
        });
      }
    } catch (e) {
      if (mounted) _toast('Impossible d\'ouvrir cette image');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _crop() async {
    final path = _imagePath;
    if (path == null || _busy) return;
    setState(() => _busy = true);
    try {
      final cropped = await ImageCropService.instance.cropImage(context, path);
      if (!mounted) return;
      if (cropped != null) setState(() => _imagePath = cropped);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _next() {
    switch (_step) {
      case _Step.image:
        setState(() => _step = _imagePath == null ? _Step.aura : _Step.crop);
        break;
      case _Step.crop:
        setState(() => _step = _Step.aura);
        break;
      case _Step.aura:
        _openEditor();
        break;
    }
  }

  void _back() {
    switch (_step) {
      case _Step.image:
        Navigator.pop(context);
        break;
      case _Step.crop:
        setState(() => _step = _Step.image);
        break;
      case _Step.aura:
        setState(() => _step = _imagePath == null ? _Step.image : _Step.crop);
        break;
    }
  }

  Future<void> _openEditor() async {
    if (_busy) return;
    setState(() => _busy = true);

    String? storedPath;
    try {
      if (_imagePath != null) {
        storedPath =
            await ImageStorageService.instance.saveImagePermanently(_imagePath!);
      }
    } catch (e) {
      storedPath = null;
      if (mounted) _toast('L\'image n\'a pas pu être enregistrée');
    }

    if (!mounted) return;
    setState(() => _busy = false);

    final now = DateTime.now();
    final note = Note(
      id: now.millisecondsSinceEpoch.toString(),
      title: '',
      content: '',
      createdAt: now,
      modifiedAt: now,
      imagePaths: storedPath == null ? [] : [storedPath],
      color: Colors.white,
      isFavorite: false,
      mood: _moodKey,
      moodColor: _moodColor,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => NoteEditScreen(note: note, onSave: widget.onSave),
      ),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.bgDark : AppTheme.bgLight;
    // 620 px etait la largeur d'un telephone : sur desktop le cadre de choix
    // de l'image paraissait etrique au milieu du vide.
    final maxWidth = Responsive.isWide(context) ? 1040.0 : 620.0;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _back,
        const SingleActivator(LogicalKeyboardKey.enter): _next,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: AnimatedContainer(
            duration: AppMotion.slow,
            curve: AppMotion.enter,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(bg, _accent, isDark ? 0.16 : 0.08)!,
                  bg,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildTopBar(isDark),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        child: AnimatedSwitcher(
                          duration: AppMotion.medium,
                          switchInCurve: AppMotion.enter,
                          switchOutCurve: AppMotion.exit,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.045),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(_step),
                            child: _buildStep(isDark),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildActions(isDark, maxWidth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    const labels = ['L\'image', 'Le cadrage', 'L\'aura'];
    final total = _imagePath == null ? 2 : 3;
    final shown = _imagePath == null
        ? [labels[0], labels[2]]
        : labels;
    final current = _imagePath == null && _step == _Step.aura ? 1 : _stepIndex;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Retour  ·  Échap',
            color: isDark ? Colors.white70 : AppTheme.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: List.generate(total, (i) {
                final done = i <= current;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == total - 1 ? 0 : 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: AppMotion.medium,
                          curve: AppMotion.enter,
                          height: 3,
                          decoration: BoxDecoration(
                            color: done
                                ? _accent
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : Colors.black.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          shown[i],
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                i == current ? FontWeight.w700 : FontWeight.w500,
                            color: i == current
                                ? (isDark ? Colors.white : AppTheme.textDark)
                                : (isDark
                                    ? AppTheme.textMutedDark
                                    : AppTheme.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(bool isDark) {
    switch (_step) {
      case _Step.image:
        return _buildImageStep(isDark);
      case _Step.crop:
        return _buildCropStep(isDark);
      case _Step.aura:
        return _buildAuraStep(isDark);
    }
  }

  // --------------------------------------------------------------- etape 1

  Widget _buildImageStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Une image pour commencer ?', isDark),
          _subtitle(
            'Elle donnera le ton de la chronique. Vous pourrez aussi vous en passer.',
            isDark,
          ),
          const SizedBox(height: 30),
          _DropZone(
            accent: _accent,
            isDark: isDark,
            busy: _busy,
            height: Responsive.isWide(context) ? 420 : 300,
            onTap: _pickImage,
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- etape 2

  Widget _buildCropStep(bool isDark) {
    final path = _imagePath;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Recadrer ?', isDark),
          _subtitle(
            'Ajustez le cadrage, ou gardez l\'image telle quelle.',
            isDark,
          ),
          const SizedBox(height: 26),
          if (path != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LayoutBuilder(
                builder: (context, c) {
                  final dpr = MediaQuery.devicePixelRatioOf(context);
                  return Image.file(
                    File(path),
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: c.maxWidth.isFinite
                        ? (c.maxWidth * dpr).round()
                        : null,
                  );
                },
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              _GhostButton(
                icon: Icons.crop_rotate_rounded,
                label: 'Recadrer',
                accent: _accent,
                isDark: isDark,
                onTap: _crop,
              ),
              const SizedBox(width: 12),
              _GhostButton(
                icon: Icons.swap_horiz_rounded,
                label: 'Changer d\'image',
                accent: _accent,
                isDark: isDark,
                onTap: _pickImage,
              ),
              const Spacer(),
              _GhostButton(
                icon: Icons.delete_outline_rounded,
                label: 'Retirer',
                accent: _accent,
                isDark: isDark,
                onTap: () => setState(() {
                  _imagePath = null;
                  _step = _Step.image;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- etape 3

  Widget _buildAuraStep(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _title('Quelle aura ?', isDark),
          _subtitle(
            'Une teinte suffit — l\'humeur est facultative, et vous pouvez '
            'écrire la vôtre.',
            isDark,
          ),
          const SizedBox(height: 22),
          Center(child: _buildPreview(isDark)),
          const SizedBox(height: 24),
          AuraChooser(
            moodKey: _moodKey,
            color: _moodColor,
            showPreview: false,
            onChanged: (choice) => setState(() {
              _moodKey = choice.moodKey;
              _moodColor = choice.color;
            }),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreview(bool isDark) {
    final hasAura = _moodKey != null;
    final path = _imagePath;

    Widget card = Container(
      width: 230,
      height: 190,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: hasAura
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (path != null)
              Image.file(File(path), fit: BoxFit.cover, cacheWidth: 520),
            if (path != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0.4, 1],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 118,
                    height: 9,
                    decoration: BoxDecoration(
                      color: (path != null
                              ? Colors.white
                              : (isDark ? Colors.white : AppTheme.textDark))
                          .withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 6,
                    decoration: BoxDecoration(
                      color: (path != null
                              ? Colors.white
                              : (isDark ? Colors.white : AppTheme.textDark))
                          .withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (hasAura) {
      card = AuraGlowWidget(
        auraColor: _accent,
        moodKey: _moodKey,
        animated: true,
        intensity: 0.95,
        child: card,
      );
    }

    return Padding(padding: const EdgeInsets.all(14), child: card);
  }

  // -------------------------------------------------------------- fragments

  Widget _title(String text, bool isDark) => Text(
        text,
        style: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.7,
          height: 1.15,
          color: isDark ? Colors.white : AppTheme.textDark,
        ),
      );

  Widget _subtitle(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.5,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
          ),
        ),
      );

  Widget _buildActions(bool isDark, double maxWidth) {
    final isLast = _step == _Step.aura;
    final secondary = switch (_step) {
      _Step.image => 'Continuer sans image',
      _Step.crop => 'Garder tel quel',
      _Step.aura => 'Sans aura',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            children: [
              if (!isLast)
                TextButton(
                  onPressed: () {
                    if (_step == _Step.image) {
                      setState(() {
                        _imagePath = null;
                        _step = _Step.aura;
                      });
                    } else {
                      _next();
                    }
                  },
                  child: Text(
                    secondary,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                    ),
                  ),
                ),
              const Spacer(),
              _PrimaryAction(
                label: isLast ? 'Écrire ma chronique' : 'Continuer',
                icon: isLast
                    ? Icons.edit_note_rounded
                    : Icons.arrow_forward_rounded,
                accent: _accent,
                busy: _busy,
                onTap: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- widgets

class _DropZone extends StatefulWidget {
  final Color accent;
  final bool isDark;
  final bool busy;
  final double height;
  final VoidCallback onTap;

  const _DropZone({
    required this.accent,
    required this.isDark,
    required this.busy,
    required this.height,
    required this.onTap,
  });

  @override
  State<_DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<_DropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.medium,
          curve: AppMotion.enter,
          // Sans largeur explicite, le Column parent (crossAxisAlignment.start)
          // laissait cette carte se retracter sur son contenu : elle restait
          // etroite quelle que soit la largeur disponible.
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.accent
                .withValues(alpha: _hover ? 0.13 : (widget.isDark ? 0.08 : 0.05)),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.accent.withValues(alpha: _hover ? 0.55 : 0.26),
              width: 1.6,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                duration: AppMotion.medium,
                curve: AppMotion.enter,
                scale: _hover ? 1.08 : 1,
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: widget.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.accent
                            .withValues(alpha: _hover ? 0.45 : 0.25),
                        blurRadius: _hover ? 24 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: widget.busy
                      ? const Padding(
                          padding: EdgeInsets.all(19),
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded,
                          color: Colors.white, size: 33),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Choisir une image',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: widget.isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'JPG, PNG ou WebP',
                style: TextStyle(
                  fontSize: 12.5,
                  color: widget.isDark
                      ? AppTheme.textMutedDark
                      : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuraChoice extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _AuraChoice({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_AuraChoice> createState() => _AuraChoiceState();
}

class _AuraChoiceState extends State<_AuraChoice> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? widget.color.withValues(alpha: 0.20)
                : (_hover
                    ? widget.color.withValues(alpha: 0.11)
                    : (widget.isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.035))),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? widget.color.withValues(alpha: 0.85)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.6),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Icon(widget.icon, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 9),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: widget.isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? Colors.white : Colors.transparent,
              width: 2.4,
            ),
            boxShadow: selected
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 14)]
                : null,
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  const _GhostButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hover
                ? widget.accent.withValues(alpha: 0.14)
                : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 17,
                  color: _hover
                      ? widget.accent
                      : (widget.isDark
                          ? Colors.white70
                          : AppTheme.textMuted)),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _hover
                      ? widget.accent
                      : (widget.isDark ? Colors.white70 : AppTheme.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color accent;
  final bool busy;
  final VoidCallback onTap;

  const _PrimaryAction({
    required this.label,
    required this.icon,
    required this.accent,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_PrimaryAction> createState() => _PrimaryActionState();
}

class _PrimaryActionState extends State<_PrimaryAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.busy ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accent,
                Color.lerp(widget.accent, Colors.black, 0.2)!,
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: _hover ? 0.48 : 0.28),
                blurRadius: _hover ? 22 : 13,
                offset: Offset(0, _hover ? 8 : 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 9),
              Icon(widget.icon, color: Colors.white, size: 19),
            ],
          ),
        ),
      ),
    );
  }
}
