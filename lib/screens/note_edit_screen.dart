import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../models/note_mood.dart';
import '../models/text_span_data.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/image_picker_helper.dart';
import '../utils/responsive.dart';
import '../widgets/aura_picker_sheet.dart';
import '../widgets/favorite_toggle.dart';
import '../widgets/save_flash.dart';
import '../widgets/rich_text_controller.dart';
import '../widgets/rich_text_field.dart';

/// Ecran d'ecriture d'une chronique.
///
/// Une seule colonne, l'image au centre, et rien d'autre a l'ecran que ce
/// qu'on est en train d'ecrire. Les reglages vivent dans une barre flottante
/// discrete en bas : ils sont a portee de main sans occuper la page.
class NoteEditScreen extends StatefulWidget {
  final Note note;
  final Function(Note) onSave;

  const NoteEditScreen({super.key, required this.note, required this.onSave});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _quoteController;
  late final RichTextEditingController _contentController;

  final _titleFocus = FocusNode();
  final _quoteFocus = FocusNode();
  final _contentFocus = FocusNode();

  late Note _note;
  bool _busy = false;
  bool _dirty = false;
  bool _savedOnce = false;
  Timer? _autoSaveTimer;

  late final String _initialTitle;
  late final String _initialQuote;
  late final String _initialContent;
  late final List<String> _initialImages;
  late final int _initialColor;
  late final bool _initialFavorite;
  late final String? _initialMood;
  late final int? _initialMoodColor;

  @override
  void initState() {
    super.initState();
    _note = widget.note.copyWith(
      imagePaths: List<String>.from(widget.note.imagePaths),
    );

    _titleController = TextEditingController(text: _note.title);
    _quoteController = TextEditingController(text: _note.quote ?? '');
    _contentController = RichTextEditingController(text: _note.content);

    if (_note.formattedContent != null && _note.formattedContent!.isNotEmpty) {
      _contentController.setFormattedContent(
        FormattedContent.fromJsonString(_note.formattedContent),
      );
    }

    _initialTitle = widget.note.title;
    _initialQuote = widget.note.quote ?? '';
    _initialContent = widget.note.content;
    _initialImages = List<String>.from(widget.note.imagePaths);
    _initialColor = widget.note.color.toARGB32();
    _initialFavorite = widget.note.isFavorite;
    _initialMood = widget.note.mood;
    _initialMoodColor = widget.note.moodColor;

    _titleController.addListener(_onEdited);
    _quoteController.addListener(_onEdited);

    // Le curseur arrive directement dans le titre : on ouvre l'ecran pour
    // ecrire, pas pour regarder un formulaire.
    if (_note.title.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _quoteController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _quoteFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- edition

  void _onEdited() {
    final dirty = _hasUnsavedChanges();
    if (dirty != _dirty && mounted) setState(() => _dirty = dirty);
    _scheduleAutoSave();
  }

  /// Enregistrement automatique local. Le champ existait dans l'ancienne
  /// version mais n'etait jamais arme : une note en cours d'ecriture etait
  /// perdue si l'application se fermait.
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || !_hasUnsavedChanges()) return;
      _collect();
      widget.onSave(_note);
      if (mounted) setState(() {
        _savedOnce = true;
        _dirty = false;
      });
    });
  }

  void _collect() {
    _note.title = _titleController.text.trim();
    final quote = _quoteController.text.trim();
    _note.quote = quote.isEmpty ? null : quote;
    _note.content = _contentController.text;
    _note.formattedContent =
        _contentController.getFormattedContent().toJsonString();
    _note.modifiedAt = DateTime.now();
  }

  bool _hasUnsavedChanges() {
    if (_titleController.text.trim() != _initialTitle) return true;
    if (_quoteController.text.trim() != _initialQuote) return true;
    if (_contentController.text != _initialContent) return true;
    if (_note.imagePaths.length != _initialImages.length) return true;
    for (var i = 0; i < _note.imagePaths.length; i++) {
      if (_note.imagePaths[i] != _initialImages[i]) return true;
    }
    if (_note.color.toARGB32() != _initialColor) return true;
    if (_note.isFavorite != _initialFavorite) return true;
    if (_note.mood != _initialMood) return true;
    if (_note.moodColor != _initialMoodColor) return true;
    return false;
  }

  void _mutate(VoidCallback change) {
    setState(() {
      change();
      _dirty = _hasUnsavedChanges();
    });
    _scheduleAutoSave();
  }

  Future<void> _save() async {
    _autoSaveTimer?.cancel();
    _collect();
    widget.onSave(_note);
    await showSaveFlash(context, color: _accent);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleBack() async {
    if (!_hasUnsavedChanges()) {
      Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => _UnsavedDialog(accent: _accent),
    );
    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'save') {
      _save();
    } else {
      Navigator.pop(context);
    }
  }

  static const int _maxImages = 3;

  Future<void> _addImage() async {
    if (_busy) return;
    if (_note.imagePaths.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trois images au maximum par chronique')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final picked = await ImagePickerHelper.pickAndOptionallyCrop(context);
      if (picked == null || !mounted) return;
      final stored =
          await ImageStorageService.instance.saveImagePermanently(picked);
      if (!mounted) return;
      _mutate(() => _note.imagePaths.add(stored));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('L\'image n\'a pas pu être ajoutée')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAura() async {
    final result = await showAuraPicker(
      context,
      moodKey: _note.mood,
      moodColor: _note.moodColor,
    );
    if (result == null || !mounted) return;
    _mutate(() {
      _note.mood = result.moodKey;
      _note.moodColor = result.color;
    });
  }

  // ------------------------------------------------------------------ style

  bool get _hasAura => _note.mood != null;

  Color get _accent => _hasAura
      ? NoteMood.getEffectiveColor(_note.mood, _note.moodColor)
      : AppTheme.skyBlue;

  int get _wordCount {
    final text = _contentController.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppTheme.bgDark : AppTheme.bgLight;
    final textColor = isDark ? AppTheme.textLight : AppTheme.textDark;
    final muted = isDark ? AppTheme.textMutedDark : AppTheme.textMuted;
    final wide = Responsive.isWide(context);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
      },
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: surface,
          body: Stack(
            children: [
              // Ambiance : l'aura teinte le fond de la page, tres doucement.
              // C'est ce qui rend l'ecran immersif sans jamais gener la
              // lecture — a l'inverse des ombres portees colorees qui etaient
              // appliquees au texte lui-meme.
              if (_hasAura)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: AppMotion.slow,
                      curve: AppMotion.enter,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -0.9),
                          radius: 1.25,
                          colors: [
                            _accent.withValues(alpha: isDark ? 0.26 : 0.13),
                            _accent.withValues(alpha: isDark ? 0.07 : 0.03),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                    ),
                  ),
                ),

              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(isDark, muted),
                    Expanded(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                              wide ? 40 : 22, 8, wide ? 40 : 22, 140),
                          child: Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 720),
                              child: _buildSheet(isDark, textColor, muted, wide),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Barre d'outils flottante
              Positioned(
                left: 0,
                right: 0,
                bottom: 22,
                child: Center(child: _buildDock(isDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- top bar

  Widget _buildTopBar(bool isDark, Color muted) {
    final status = _dirty
        ? 'Brouillon'
        : (_savedOnce ? 'Enregistré' : 'Prêt');

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 14, 2),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Retour',
            color: muted,
          ),
          const Spacer(),
          AnimatedContainer(
            duration: AppMotion.fast,
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _dirty ? const Color(0xFFD9A441) : const Color(0xFF3E9E74),
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          const SizedBox(width: 14),
          _SaveButton(accent: _accent, onTap: _save),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ page

  Widget _buildSheet(
      bool isDark, Color textColor, Color muted, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_note.imagePaths.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CenteredImages(
            paths: _note.imagePaths,
            accent: _hasAura ? _accent : null,
            onRemove: (i) => _mutate(() => _note.imagePaths.removeAt(i)),
          ),
          const SizedBox(height: 34),
        ] else
          const SizedBox(height: 18),

        // Titre
        TextField(
          controller: _titleController,
          focusNode: _titleFocus,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          cursorColor: _accent,
          cursorWidth: 2.5,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _contentFocus.requestFocus(),
          style: TextStyle(
            fontSize: wide ? 36 : 29,
            fontWeight: FontWeight.w800,
            height: 1.18,
            letterSpacing: -0.8,
            color: textColor,
          ),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            // Le theme de l'application force `filled: true` : sans ce
            // reglage, chaque champ dessine un rectangle opaque et on a
            // l'impression de remplir un formulaire au lieu d'ecrire.
            filled: false,
            fillColor: Colors.transparent,
            // Le theme declare aussi enabledBorder et focusedBorder : sans
            // les neutraliser, un liseré subsiste et trahit le champ.
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            hintText: 'Un titre…',
            hintStyle: TextStyle(
              fontSize: wide ? 36 : 29,
              fontWeight: FontWeight.w800,
              height: 1.18,
              letterSpacing: -0.8,
              color: muted.withValues(alpha: 0.38),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Citation
        Container(
          padding: const EdgeInsets.only(left: 15),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _accent.withValues(alpha: 0.5),
                width: 3,
              ),
            ),
          ),
          child: TextField(
            controller: _quoteController,
            focusNode: _quoteFocus,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: _accent,
            style: TextStyle(
              fontSize: 16.5,
              fontStyle: FontStyle.italic,
              height: 1.5,
              color: textColor.withValues(alpha: 0.85),
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              filled: false,
              fillColor: Colors.transparent,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              hintText: 'Une phrase à retenir',
              hintStyle: TextStyle(
                fontSize: 16.5,
                fontStyle: FontStyle.italic,
                height: 1.5,
                color: muted.withValues(alpha: 0.42),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),

        // Corps
        RichTextField(
          controller: _contentController,
          focusNode: _contentFocus,
          cursorColor: _accent,
          placeholder: 'Racontez votre journée…',
          baseStyle: TextStyle(
            fontSize: 16.5,
            height: 1.85,
            color: textColor.withValues(alpha: 0.92),
          ),
          onChanged: (_) => _onEdited(),
        ),

        const SizedBox(height: 26),
        // Compteur discret : un petit retour sur l'effort fourni, qui donne
        // envie de continuer une ligne de plus.
        AnimatedOpacity(
          duration: AppMotion.medium,
          opacity: _wordCount == 0 ? 0 : 1,
          child: Text(
            _wordCount <= 1 ? '$_wordCount mot' : '$_wordCount mots',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: muted.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ dock

  Widget _buildDock(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: (isDark ? AppTheme.surfaceDark : Colors.white)
            .withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.42 : 0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DockButton(
            icon: Icons.add_photo_alternate_outlined,
            label: 'Image',
            tooltip: 'Ajouter une image',
            active: _note.imagePaths.isNotEmpty,
            accent: AppTheme.skyBlue,
            isDark: isDark,
            busy: _busy,
            onTap: _addImage,
          ),
          const SizedBox(width: 6),
          _DockButton(
            icon: _hasAura
                ? Icons.auto_awesome_rounded
                : Icons.auto_awesome_outlined,
            label: _hasAura ? NoteMood.getDisplayLabel(_note.mood) : 'Aura',
            tooltip: 'Choisir une aura',
            active: _hasAura,
            accent: _accent,
            isDark: isDark,
            onTap: _openAura,
          ),
          const SizedBox(width: 6),
          _DockFavorite(
            isFavorite: _note.isFavorite,
            isDark: isDark,
            onChanged: (v) => _mutate(() => _note.isFavorite = v),
          ),
        ],
      ),
    );
  }
}

// =========================================================== sous-composants

/// Images au-dessus du texte : cote a cote, jamais empilees.
///
/// Trois au maximum, et chacune retrecit pour que la rangee tienne toujours
/// dans la colonne de lecture.
class _CenteredImages extends StatelessWidget {
  final List<String> paths;
  final Color? accent;
  final ValueChanged<int> onRemove;

  const _CenteredImages({
    required this.paths,
    required this.accent,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final glow = accent ?? Colors.black;
    final count = paths.length;

    // Une seule image respire ; a plusieurs on baisse la hauteur pour que la
    // rangee reste equilibree.
    final height = count == 1 ? 230.0 : (count == 2 ? 190.0 : 160.0);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) => Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: glow.withValues(alpha: 0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 9),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(paths[i]),
                          fit: BoxFit.cover,
                          cacheWidth: c.maxWidth.isFinite && c.maxWidth > 0
                              ? (c.maxWidth * dpr).round()
                              : null,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black26,
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: _RemoveDot(
                        small: count > 1,
                        onTap: () => onRemove(i),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoveDot extends StatelessWidget {
  final VoidCallback onTap;
  final bool small;

  const _RemoveDot({required this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(small ? 3 : 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.close_rounded,
              size: small ? 12 : 16, color: Colors.white),
        ),
      ),
    );
  }
}

class _DockButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
  final Color accent;
  final bool isDark;
  final bool busy;
  final VoidCallback onTap;

  const _DockButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
    required this.accent,
    required this.isDark,
    this.busy = false,
    required this.onTap,
  });

  @override
  State<_DockButton> createState() => _DockButtonState();
}

class _DockButtonState extends State<_DockButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.active;
    final color = on || _hover
        ? widget.accent
        : (widget.isDark ? AppTheme.textMutedDark : AppTheme.textMuted);

    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.busy ? null : widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            constraints: const BoxConstraints(minWidth: 84),
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: on
                  ? widget.accent.withValues(alpha: 0.15)
                  : (_hover
                      ? widget.accent.withValues(alpha: 0.09)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: widget.accent),
                  )
                else
                  Icon(widget.icon, size: 19, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: color,
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

class _SaveButton extends StatefulWidget {
  final Color accent;
  final VoidCallback onTap;

  const _SaveButton({required this.accent, required this.onTap});

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Enregistrer  ·  Ctrl+S',
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: widget.accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: widget.accent.withValues(alpha: _hover ? 0.45 : 0.25),
                  blurRadius: _hover ? 18 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, color: Colors.white, size: 17),
                SizedBox(width: 7),
                Text(
                  'Enregistrer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

class _UnsavedDialog extends StatelessWidget {
  final Color accent;

  const _UnsavedDialog({required this.accent});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Enregistrer avant de quitter ?'),
      content: const Text('Cette chronique contient des modifications.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'cancel'),
          child: const Text('Continuer d\'écrire'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'discard'),
          child: const Text('Abandonner',
              style: TextStyle(color: Color(0xFFD1544B))),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, 'save'),
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}

/// Bouton favori de la barre flottante : meme animation que partout ailleurs.
class _DockFavorite extends StatelessWidget {
  final bool isFavorite;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _DockFavorite({
    required this.isFavorite,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE05252);
    return AnimatedContainer(
      duration: AppMotion.fast,
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isFavorite
            ? accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FavoriteToggle(
            isFavorite: isFavorite,
            onChanged: onChanged,
            size: 19,
            inactiveColor:
                isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
          ),
          Flexible(
            child: GestureDetector(
              onTap: () => onChanged(!isFavorite),
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'Favori',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        isFavorite ? FontWeight.w700 : FontWeight.w600,
                    color: isFavorite
                        ? accent
                        : (isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMuted),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
