import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note.dart';
import '../models/text_span_data.dart';
import '../widgets/color_picker.dart';
import '../widgets/image_gallery_editor.dart';
import '../widgets/rich_text_controller.dart';
import '../widgets/rich_text_field.dart';
import '../services/image_storage_service.dart';
import '../services/image_crop_service.dart';
import '../theme/app_theme.dart';

class NoteEditScreen extends StatefulWidget {
  final Note note;
  final Function(Note) onSave;

  const NoteEditScreen({super.key, required this.note, required this.onSave});

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late TextEditingController _titleController;
  late RichTextEditingController _contentController;
  late Note _note;
  final _imagePicker = ImagePicker();
  final _titleFocus = FocusNode();
  final _contentFocus = FocusNode();
  bool _isSaving = false;

  // Pour tracker les changements non enregistres
  late String _initialTitle;
  late String _initialContent;
  late List<String> _initialImages;
  late int _initialColor;
  late bool _initialFavorite;

  @override
  void initState() {
    super.initState();
    _note = Note(
      id: widget.note.id,
      title: widget.note.title,
      content: widget.note.content,
      formattedContent: widget.note.formattedContent,
      createdAt: widget.note.createdAt,
      modifiedAt: widget.note.modifiedAt,
      imagePaths: List.from(widget.note.imagePaths),
      color: widget.note.color,
      isFavorite: widget.note.isFavorite,
    );
    _titleController = TextEditingController(text: _note.title);
    _contentController = RichTextEditingController(text: _note.content);
    
    // Charger le contenu formaté s'il existe
    if (_note.formattedContent != null && _note.formattedContent!.isNotEmpty) {
      _contentController.setFormattedContent(
        FormattedContent.fromJsonString(_note.formattedContent),
      );
    }

    // Sauvegarder l'etat initial
    _initialTitle = widget.note.title;
    _initialContent = widget.note.content;
    _initialImages = List.from(widget.note.imagePaths);
    _initialColor = widget.note.color.value;
    _initialFavorite = widget.note.isFavorite;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _titleFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    final currentTitle = _titleController.text.trim();
    final currentContent = _contentController.text.trim();

    // Verifier si le contenu est vide (nouvelle story sans contenu)
    if (currentTitle.isEmpty &&
        currentContent.isEmpty &&
        _note.imagePaths.isEmpty) {
      return false;
    }

    return currentTitle != _initialTitle ||
        currentContent != _initialContent ||
        _note.imagePaths.length != _initialImages.length ||
        !_listEquals(_note.imagePaths, _initialImages) ||
        _note.color.value != _initialColor ||
        _note.isFavorite != _initialFavorite;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<bool> _showUnsavedChangesDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  color: AppTheme.skyBlue, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Modifications non enregistrees',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Vous avez des modifications non enregistrees. Voulez-vous les sauvegarder avant de quitter ?',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Quitter',
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Enregistrer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _handleBack() async {
    if (_hasUnsavedChanges()) {
      final shouldSave = await _showUnsavedChangesDialog();
      if (shouldSave) {
        _save();
      } else {
        Navigator.pop(context);
      }
    } else {
      Navigator.pop(context);
    }
  }

  void _save() {
    _note.title = _titleController.text.trim();
    // On ne trim() pas le content ici pour garder la cohérence avec les spans du RichText
    // Le RichTextEditingController gère déjà son propre état
    final formatted = _contentController.getFormattedContent();
    _note.content = _contentController.text; 
    _note.formattedContent = formatted.toJsonString();
    _note.modifiedAt = DateTime.now();
    widget.onSave(_note);
    Navigator.pop(context);
  }

  Future<void> _pickImage() async {
    setState(() => _isSaving = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      if (image != null) {
        // Proposer le recadrage
        final croppedPath = await ImageCropService.instance.cropImage(context, image.path);
        final finalPath = croppedPath ?? image.path; // Si annulé, on garde l'original ou on ignore ? 
        // L'utilisateur demande "donne la possibilité de resizer", donc on l'integre.
        
        final path =
            await ImageStorageService.instance.saveImagePermanently(finalPath);
        setState(() => _note.imagePaths.add(path));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Couleur de la story',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ColorPicker(
              selectedColor: _note.color,
              onColorChanged: (c) {
                setState(() => _note.color = c);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageColor = isDark ? AppTheme.surfaceDark : _note.color;
    final textColor = _getTextColor(pageColor, isDark);

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: AppTheme.skyBlue,
      statusBarIconBrightness: Brightness.light,
    ));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(textColor, isDark),
              // Page effet
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  decoration: BoxDecoration(
                    color: pageColor,
                    borderRadius: BorderRadius.circular(24),
                    border: _note.color == Colors.white && !isDark
                        ? Border.all(color: Colors.grey.shade200)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.3)
                            : Colors.black.withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Images
                          if (_note.imagePaths.isNotEmpty) ...[
                            ImageGalleryEditor(
                              imagePaths: _note.imagePaths,
                              onRemove: (i) =>
                                  setState(() => _note.imagePaths.removeAt(i)),
                              textColor: textColor,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Titre - style page
                          EditableText(
                            controller: _titleController,
                            focusNode: _titleFocus,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1.3,
                            ),
                            cursorColor: AppTheme.skyBlue,
                            backgroundCursorColor: Colors.grey,
                            maxLines: null,
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_titleController.text.isEmpty)
                            GestureDetector(
                              onTap: () => _titleFocus.requestFocus(),
                              child: Text(
                                'Titre',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: textColor.withOpacity(0.25),
                                  height: 1.3,
                                ),
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Ligne décorative
                          Container(
                            height: 2,
                            width: 60,
                            decoration: BoxDecoration(
                              color: textColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Contenu - style page avec formatage riche
                          RichTextField(
                            controller: _contentController,
                            focusNode: _contentFocus,
                            baseStyle: TextStyle(
                              fontSize: 16,
                              color: textColor.withOpacity(0.85),
                              height: 1.8,
                            ),
                            placeholder: 'Commencez à écrire...',
                            cursorColor: AppTheme.skyBlue,
                            onChanged: (_) => setState(() {}),
                          ),

                          const SizedBox(height: 200),
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
    );
  }

  Widget _buildTopBar(Color textColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Row(
        children: [
          // Retour
          IconButton(
            onPressed: _handleBack,
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? AppTheme.textLight : AppTheme.textDark),
          ),
          const Spacer(),
          // Couleur
          _buildTool(Icons.palette_outlined, _showColorPicker, isDark),
          const SizedBox(width: 6),
          // Image
          _isSaving
              ? Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              isDark ? AppTheme.textLight : AppTheme.textDark)),
                )
              : _buildTool(Icons.image_outlined, _pickImage, isDark),
          const SizedBox(width: 6),
          // Favori
          _buildTool(
            _note.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_outline_rounded,
            () => setState(() => _note.isFavorite = !_note.isFavorite),
            isDark,
            color: _note.isFavorite ? AppTheme.skyBlue : null,
          ),
          const SizedBox(width: 12),
          // Save
          GestureDetector(
            onTap: _save,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 6),
                  Text('OK',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTool(IconData icon, VoidCallback onTap, bool isDark,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 20,
            color: color ?? (isDark ? AppTheme.textLight : AppTheme.textDark)),
      ),
    );
  }

  Color _getTextColor(Color bg, bool isDark) {
    if (isDark) return AppTheme.textLight;
    return bg.computeLuminance() > 0.5 ? AppTheme.textDark : Colors.white;
  }
}
