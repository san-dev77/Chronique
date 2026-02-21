import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../models/note.dart';
import '../models/note_mood.dart';
import '../models/text_span_data.dart';
import '../widgets/color_picker.dart';
import '../widgets/image_gallery_editor.dart';
import '../widgets/rich_text_controller.dart';
import '../widgets/rich_text_field.dart';
import '../services/image_storage_service.dart';
import '../services/image_crop_service.dart';
import '../services/spark_service.dart';
import '../models/spark.dart';
import '../utils/image_picker_helper.dart';
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
  late String? _initialMood;
  late int? _initialMoodColor;

  List<Spark> _availableSparks = [];
  bool _showSparks = false;

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
      mood: widget.note.mood,
      moodColor: widget.note.moodColor,
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
    _initialMood = widget.note.mood;
    _initialMoodColor = widget.note.moodColor;

    // Charger les étincelles pour suggestions
    _loadSparks();
  }

  void _loadSparks() {
    final sparks = SparkService.instance.getAllSparks();
    setState(() {
      _availableSparks = sparks;
      // Afficher seulement si la note est neuve (pas de titre, pas de contenu)
      _showSparks = widget.note.title.isEmpty && widget.note.content.isEmpty;
    });
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

    // Verifier si le contenu est vide (nouvelle chronique sans contenu)
    if (_titleController.text.trim() != _initialTitle) return true;
    if (_contentController.text != _initialContent) return true;
    if (!_listEquals(_note.imagePaths, _initialImages)) return true;
    if (_note.color.value != _initialColor) return true;
    if (_note.isFavorite != _initialFavorite) return true;
    if (_note.mood != _initialMood) return true;
    if (_note.moodColor != _initialMoodColor) return true;
    return false;
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
      final String? finalPath =
          await ImagePickerHelper.pickAndOptionallyCrop(context);

      if (finalPath != null) {
        final path =
            await ImageStorageService.instance.saveImagePermanently(finalPath);
        setState(() => _note.imagePaths.add(path));
      }
    } catch (e) {
      debugPrint('Erreur lors de la sélection de l\'image: $e');
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
            const Text('Couleur de la chronique',
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

  void _showMoodPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Titre
            Text(
              'Aura de la chronique',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quelle énergie porte cette chronique ?',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            // Grid des auras
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: NoteMood.all.length,
              itemBuilder: (context, index) {
                final mood = NoteMood.all[index];
                final isSelected = _note.mood == mood.key;
                final effectiveColor = NoteMood.getEffectiveColor(
                  mood.key,
                  isSelected ? _note.moodColor : null,
                );

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_note.mood == mood.key) {
                        // Deselect
                        _note.mood = null;
                        _note.moodColor = null;
                      } else {
                        _note.mood = mood.key;
                        // Garder la couleur custom seulement si on re-sélectionne la même
                        if (_note.mood != mood.key) _note.moodColor = null;
                      }
                    });
                    Navigator.pop(context);
                  },
                  onLongPress: () {
                    // Long press = choisir couleur custom pour cette aura
                    Navigator.pop(context);
                    _showCustomMoodColorPicker(mood);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? effectiveColor.withOpacity(0.2)
                          : (isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade50),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? effectiveColor : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: effectiveColor.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(mood.icon,
                            size: 24,
                            color: isSelected
                                ? effectiveColor
                                : (isDark
                                    ? Colors.white60
                                    : Colors.grey.shade500)),
                        const SizedBox(height: 6),
                        Text(
                          mood.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? effectiveColor
                                : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Maintenir appuyé pour personnaliser la couleur',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomMoodColorPicker(NoteMood mood) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
      Colors.grey,
      mood.defaultColor,
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Couleur de l\'aura "${mood.label}"',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: colors.map((c) {
                final isDefault = c == mood.defaultColor;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _note.mood = mood.key;
                      _note.moodColor = isDefault ? null : c.value;
                    });
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDefault ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: c.withOpacity(0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: isDefault
                        ? const Icon(Icons.auto_awesome,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
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
                      if (NoteMood.hasGlow(_note.mood)) ...[
                        BoxShadow(
                          color: NoteMood.getEffectiveColor(
                                  _note.mood, _note.moodColor)
                              .withOpacity(0.35),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: NoteMood.getEffectiveColor(
                                  _note.mood, _note.moodColor)
                              .withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ] else
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
                          // Suggestions d'étincelles (supprimées d'ici, déplacées en BottomSheet)

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
                          Stack(
                            children: [
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
                                onChanged: (_) {},
                              ),
                              // Placeholder via ValueListenableBuilder
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _titleController,
                                builder: (context, value, child) {
                                  if (value.text.isNotEmpty)
                                    return const SizedBox.shrink();
                                  return IgnorePointer(
                                    child: GestureDetector(
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
                                  );
                                },
                              ),
                            ],
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
                            onChanged: (_) {
                              // On ne fait plus de setState ici pour éviter de casser la composition du clavier
                            },
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
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          // Retour
          IconButton(
            onPressed: _handleBack,
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? AppTheme.textLight : AppTheme.textDark),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          // Outils scrollables
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Inspiration / Étincelles
                  if (_availableSparks.isNotEmpty) ...[
                    _buildTool(Icons.lightbulb_outline_rounded,
                        () => _showInspirationSheet(isDark), isDark,
                        color: AppTheme.skyBlue),
                    const SizedBox(width: 4),
                  ],
                  // Aura
                  _buildTool(
                    _note.mood != null
                        ? Icons.auto_awesome_rounded
                        : Icons.auto_awesome_outlined,
                    _showMoodPicker,
                    isDark,
                    color: _note.mood != null
                        ? NoteMood.getEffectiveColor(
                            _note.mood, _note.moodColor)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  // Couleur
                  _buildTool(Icons.palette_outlined, _showColorPicker, isDark),
                  const SizedBox(width: 4),
                  // Image
                  _isSaving
                      ? Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark
                                      ? AppTheme.textLight
                                      : AppTheme.textDark)),
                        )
                      : _buildTool(Icons.image_outlined, _pickImage, isDark),
                  const SizedBox(width: 4),
                  // Favori
                  _buildTool(
                    _note.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    () => setState(() => _note.isFavorite = !_note.isFavorite),
                    isDark,
                    color: _note.isFavorite ? AppTheme.skyBlue : null,
                  ),
                  const SizedBox(width: 8),
                  // Save
                  GestureDetector(
                    onTap: _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.skyBlue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 18,
            color: color ?? (isDark ? AppTheme.textLight : AppTheme.textDark)),
      ),
    );
  }

  Color _getTextColor(Color bg, bool isDark) {
    if (isDark) return AppTheme.textLight;
    return bg.computeLuminance() > 0.5 ? AppTheme.textDark : Colors.white;
  }

  void _showInspirationSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.skyBlue, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Inspirations (Étincelles)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                itemCount: _availableSparks.length,
                itemBuilder: (context, index) {
                  final spark = _availableSparks[index];
                  return _buildSparkInspirationCard(spark, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSparkInspirationCard(Spark spark, bool isDark) {
    return GestureDetector(
      onTap: () => _confirmApplySpark(spark),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.skyBlue.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (spark.imagePath != null)
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.file(
                    File(spark.imagePath!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Icon(Icons.lightbulb_outline_rounded,
                      color: AppTheme.skyBlue.withOpacity(0.2), size: 40),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                spark.title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmApplySpark(Spark spark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Appliquer l\'étincelle ?'),
        content: const Text(
            'Cela remplacera le titre et le contenu actuel de votre chronique.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Dialog
              Navigator.pop(context); // BottomSheet
              _applySpark(spark);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  void _applySpark(Spark spark) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    setState(() {
      _titleController.text = spark.title;
      if (spark.description != null) {
        _contentController.text = spark.description!;
      }
      if (spark.imagePath != null) {
        _note.imagePaths.add(spark.imagePath!);
      }
      _showSparks = false;
    });

    // Suggestion : supprimer l'étincelle après utilisation pour "ranger"
    // Style premium pour la SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: Colors.white.withOpacity(0.9), size: 20),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'L\'inspiration a été appliquée !',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppTheme.cardDark : AppTheme.skyBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        elevation: 6,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
