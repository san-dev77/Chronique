import 'dart:io';
import 'package:flutter/material.dart';
import '../models/spark.dart';
import '../services/spark_service.dart';
import '../utils/image_picker_helper.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

class SparkEditScreen extends StatefulWidget {
  final Spark? spark;
  final Function(Spark) onSave;

  const SparkEditScreen({super.key, this.spark, required this.onSave});

  @override
  State<SparkEditScreen> createState() => _SparkEditScreenState();
}

class _SparkEditScreenState extends State<SparkEditScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String? _imagePath;
  bool _isSaving = false;

  // Etat d'origine : sans lui, ouvrir une etincelle pour la relire declenchait
  // toujours la demande d'enregistrement, puisque les champs n'etaient pas vides.
  late final String _initialTitle;
  late final String _initialDescription;
  late final String? _initialImagePath;

  @override
  void initState() {
    super.initState();
    _initialTitle = widget.spark?.title ?? '';
    _initialDescription = widget.spark?.description ?? '';
    _initialImagePath = widget.spark?.imagePath;

    _titleController = TextEditingController(text: _initialTitle);
    _descriptionController = TextEditingController(text: _initialDescription);
    _imagePath = _initialImagePath;
  }

  /// Vrai seulement si quelque chose a reellement change.
  bool get _hasChanges {
    if (_titleController.text.trim() != _initialTitle.trim()) return true;
    if (_descriptionController.text.trim() != _initialDescription.trim()) {
      return true;
    }
    if (_imagePath != _initialImagePath) return true;
    return false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final String? path = await ImagePickerHelper.pickAndOptionallyCrop(context);
    if (path != null) {
      final permanentPath =
          await ImageStorageService.instance.saveImagePermanently(path);
      setState(() => _imagePath = permanentPath);
    }
  }

  Future<bool> _onWillPop() async {
    // Rien de modifie : on sort sans rien demander.
    if (!_hasChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enregistrer l\'étincelle ?'),
        content: const Text(
            'Souhaitez-vous sauvegarder votre idée avant de quitter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Annuler / Rester
            child:
                Text('Rester', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // Quitter sans save
            child: const Text('Quitter sans save',
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              _save();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez donner un nom à votre étincelle')),
      );
      return;
    }

    final spark = Spark(
      id: widget.spark?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      imagePath: _imagePath,
      createdAt: widget.spark?.createdAt ?? DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    widget.onSave(spark);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: isDark ? AppTheme.textLight : AppTheme.textDark),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) Navigator.pop(context);
            },
          ),
          title: Text(
            widget.spark == null
                ? 'Nouvelle Étincelle'
                : 'Modifier l\'Étincelle',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? AppTheme.textLight : AppTheme.textDark,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: GestureDetector(
                onTap: _save,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Sauver',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          // Bornage : sur desktop la saisie s'etirait sur toute la fenetre.
          child: ContentBounds(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              // Image Preview/Picker - simplified like NoteEditScreen image tool
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: _imagePath != null ? 280 : 120,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.03),
                    ),
                    image: _imagePath != null
                        ? DecorationImage(
                            // Un DecorationImage n'a pas de cacheWidth :
                            // ResizeImage joue le meme role, sans quoi la
                            // photo est decodee en pleine resolution.
                            image: ResizeImage(
                              FileImage(File(_imagePath!)),
                              width: (MediaQuery.sizeOf(context).width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                            ),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _imagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined,
                                size: 32,
                                color: isDark
                                    ? Colors.white24
                                    : Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text(
                              'Ajouter une image',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white24
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            Positioned(
                              top: 12,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => setState(() => _imagePath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 32),

              // Title Input - direct on background
              TextField(
                controller: _titleController,
                autofocus: widget.spark == null,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.textLight : AppTheme.textDark,
                  height: 1.3,
                ),
                decoration: InputDecoration(
                  hintText: 'Une idée ? Tapotez ici...',
                  hintStyle: TextStyle(
                      color: isDark
                          ? Colors.white.withOpacity(0.15)
                          : Colors.black.withOpacity(0.1)),
                  // Le theme impose filled:true et ses propres bordures :
                  // sans les neutraliser, le champ dessine un rectangle.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: 8),
              Container(
                height: 2,
                width: 40,
                decoration: BoxDecoration(
                  color: (isDark ? AppTheme.textLight : AppTheme.textDark)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 24),

              // Description Input - direct on background
              TextField(
                controller: _descriptionController,
                maxLines: null,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.8,
                  color: isDark
                      ? AppTheme.textLight.withOpacity(0.8)
                      : AppTheme.textDark.withOpacity(0.8),
                ),
                decoration: InputDecoration(
                  hintText: 'Développez votre étincelle (optionnel)...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.1),
                    fontSize: 18,
                  ),
                  // Le theme impose filled:true et ses propres bordures :
                  // sans les neutraliser, le champ dessine un rectangle.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
