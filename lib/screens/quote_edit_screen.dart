import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import '../models/note_mood.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';
import '../widgets/save_flash.dart';

/// Editeur d'une citation.
///
/// Une citation est une chronique dont le coeur est la phrase : pas de corps
/// de texte, pas d'images, pas de parcours guide. Elle merite donc son propre
/// ecran plutot qu'un champ perdu dans l'editeur complet — on y vient pour
/// poser une phrase et son auteur, rien d'autre.
///
/// Elle est enregistree comme une Note portant `quote`. Rien de nouveau a
/// stocker, rien de nouveau a synchroniser : les citations deja ecrites dans
/// des chroniques apparaissent donc tout de suite dans leur espace.
class QuoteEditScreen extends StatefulWidget {
  final Note? note;
  final Future<void> Function(Note note, {bool isNew}) onSave;

  const QuoteEditScreen({super.key, this.note, required this.onSave});

  @override
  State<QuoteEditScreen> createState() => _QuoteEditScreenState();
}

class _QuoteEditScreenState extends State<QuoteEditScreen> {
  late final TextEditingController _quote =
      TextEditingController(text: widget.note?.quote ?? '');
  late final TextEditingController _author =
      TextEditingController(text: widget.note?.title ?? '');
  final _quoteFocus = FocusNode();

  // La teinte de l'application par defaut : la premiere couleur de la
  // palette donnait un violet sans rapport avec le reste de l'ecran.
  late int _color = widget.note?.moodColor ?? AppTheme.skyBlue.toARGB32();

  /// Epinglee : elle remonte en tete des Citations.
  late bool _pinned = widget.note?.isPinned ?? false;
  bool _saving = false;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    // On arrive pour ecrire : le curseur est deja dans la phrase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isNew) _quoteFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _quote.dispose();
    _author.dispose();
    _quoteFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _quote.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Une citation a besoin de sa phrase.'),
      ));
      _quoteFocus.requestFocus();
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);

    final now = DateTime.now();
    final base = widget.note;
    final note = Note(
      id: base?.id ?? now.microsecondsSinceEpoch.toString(),
      // L'auteur tient lieu de titre : c'est ce qui s'affiche partout
      // ailleurs dans l'application.
      title: _author.text.trim(),
      content: base?.content ?? '',
      formattedContent: base?.formattedContent,
      quote: text,
      createdAt: base?.createdAt ?? now,
      modifiedAt: now,
      imagePaths: base?.imagePaths ?? const [],
      imageHashes: base?.imageHashes ?? const [],
      color: base?.color ?? Colors.white,
      isFavorite: base?.isFavorite ?? false,
      isPinned: _pinned,
      // Une couleur sans humeur imposee : la citation porte sa teinte.
      mood: base?.mood ?? NoteMood.freeKey,
      moodColor: _color,
    );

    await widget.onSave(note, isNew: _isNew);
    if (!mounted) return;
    await showSaveFlash(context);
    if (mounted) Navigator.pop(context, note);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = Color(_color);
    final wide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgDark : AppTheme.bgLight,
      body: Shortcuts(
        shortcuts: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true):
              const _SaveIntent(),
        },
        child: Actions(
          actions: {
            _SaveIntent: CallbackAction<_SaveIntent>(
              onInvoke: (_) {
                _save();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: false,
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      _buildBar(isDark, tint, wide),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                              wide ? 36 : 22, 10, wide ? 36 : 22, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildSheet(isDark, tint, wide),
                              const SizedBox(height: 26),
                              _buildPalette(isDark),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBar(bool isDark, Color tint, bool wide) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 26 : 12, 10, wide ? 26 : 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Retour',
            color: isDark ? Colors.white70 : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _isNew ? 'Nouvelle citation' : 'Citation',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: isDark ? Colors.white : AppTheme.textDark,
              ),
            ),
          ),
          _PinToggle(
            pinned: _pinned,
            tint: tint,
            isDark: isDark,
            onTap: () => setState(() => _pinned = !_pinned),
          ),
          const SizedBox(width: 10),
          _SaveButton(
            accent: tint,
            busy: _saving,
            onTap: _save,
          ),
        ],
      ),
    );
  }

  /// La feuille ou vit la phrase.
  ///
  /// Aucun liseré de champ : on ne doit pas voir qu'il s'agit d'un formulaire.
  /// Le guillemet et la teinte font tout le decor.
  Widget _buildSheet(bool isDark, Color tint, bool wide) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          wide ? 34 : 22, wide ? 30 : 24, wide ? 34 : 22, wide ? 28 : 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(isDark ? AppTheme.surfaceDark : Colors.white, tint,
                isDark ? 0.16 : 0.07)!,
            isDark ? AppTheme.surfaceDark : Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tint.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: isDark ? 0.20 : 0.14),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded,
              size: wide ? 42 : 34, color: tint.withValues(alpha: 0.55)),
          const SizedBox(height: 6),
          TextField(
            controller: _quote,
            focusNode: _quoteFocus,
            maxLines: null,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
              fontSize: wide ? 25 : 21,
              height: 1.45,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.3,
              color: isDark ? Colors.white : AppTheme.textDark,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'La phrase qui vous a arrêté…',
              hintStyle: TextStyle(
                fontSize: wide ? 25 : 21,
                height: 1.45,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 22,
                height: 2,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _author,
                  maxLines: 1,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: isDark ? Colors.white70 : AppTheme.textMuted,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'De qui ? (facultatif)',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPalette(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TEINTE',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: isDark
                ? Colors.white.withValues(alpha: 0.32)
                : AppTheme.textMuted.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in NoteMood.palette)
              _Swatch(
                color: color,
                selected: color.toARGB32() == _color,
                onTap: () => setState(() => _color = color.toARGB32()),
              ),
          ],
        ),
      ],
    );
  }
}

/// L'epingle de l'editeur : elle marque la phrase avant meme de l'enregistrer.
class _PinToggle extends StatefulWidget {
  final bool pinned;
  final Color tint;
  final bool isDark;
  final VoidCallback onTap;

  const _PinToggle({
    required this.pinned,
    required this.tint,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PinToggle> createState() => _PinToggleState();
}

class _PinToggleState extends State<_PinToggle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.pinned;
    return Tooltip(
      message: active
          ? 'Épinglée — elle remonte en tête des Citations'
          : 'Épingler cette phrase',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: active
                  ? widget.tint.withValues(alpha: widget.isDark ? 0.26 : 0.16)
                  : (_hover
                      ? widget.tint.withValues(alpha: 0.10)
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.black.withValues(alpha: 0.035))),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? widget.tint.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedRotation(
                  duration: AppMotion.medium,
                  curve: AppMotion.emphasized,
                  turns: active ? 0 : -0.1,
                  child: Icon(
                    active
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 17,
                    color: active
                        ? widget.tint
                        : (widget.isDark
                            ? AppTheme.textMutedDark
                            : AppTheme.textMuted),
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 7),
                  Text(
                    'Épinglée',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? Colors.white
                          : Color.lerp(widget.tint, Colors.black, 0.35),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _Swatch extends StatefulWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.enter,
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withValues(alpha: _hover ? 0.6 : 0),
              width: selected ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color
                    .withValues(alpha: selected || _hover ? 0.55 : 0.22),
                blurRadius: selected ? 14 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
              : null,
        ),
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  final Color accent;
  final bool busy;
  final VoidCallback onTap;

  const _SaveButton({
    required this.accent,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Tooltip(
      message: 'Enregistrer  ·  Ctrl+S',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.busy ? null : widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.enter,
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(accent, Colors.white, _hover ? 0.16 : 0.06)!,
                  Color.lerp(accent, Colors.black, 0.24)!,
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: _hover ? 0.44 : 0.26),
                  blurRadius: _hover ? 18 : 11,
                  offset: Offset(0, _hover ? 6 : 3),
                ),
              ],
            ),
            child: Center(
              child: widget.busy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
